CREATE OR REPLACE FUNCTION public._rebuild_sales_log_for_order(p_order_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.orders%rowtype;
  item jsonb;
  item_pos integer;
  qty integer;
  unit_pos integer;
  v_book_id uuid;
  v_telegram_book_id bigint;
  v_title text;
  v_unit_price integer;
  v_unit_cost integer;
  v_sold_at timestamptz;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found then return; end if;

  if not (o.status = 'shipping' or
      (coalesce(o.source, 'app') in ('app', 'telegram') and o.status in ('accepted', 'paid'))) then
    delete from public.sales_log where order_id = o.id;
    return;
  end if;

  select min(sold_at) into v_sold_at from public.sales_log where order_id = o.id;
  v_sold_at := coalesce(v_sold_at, o.updated_at, o.created_at, now());
  delete from public.sales_log where order_id = o.id;

  for item, item_pos in
    select value, ordinality::integer
    from jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) with ordinality
  loop
    begin
      qty := greatest(1, coalesce(nullif(item->>'quantity','')::integer, nullif(item->>'qty','')::integer, 1));
    exception when others then qty := 1; end;

    begin v_book_id := nullif(item->>'book_id','')::uuid;
    exception when others then v_book_id := null; end;
    begin v_telegram_book_id := nullif(item->>'telegram_book_id','')::bigint;
    exception when others then v_telegram_book_id := null; end;

    v_title := coalesce(nullif(trim(item->>'title'),''), nullif(trim(item->>'name'),''), 'Kitob');
    begin
      v_unit_price := greatest(0, coalesce(nullif(item->>'unit_price','')::integer, nullif(item->>'price','')::integer, 0));
    exception when others then v_unit_price := 0; end;

    begin
      v_unit_cost := greatest(0, coalesce(nullif(item->>'unit_cost','')::integer, 0));
    exception when others then v_unit_cost := 0; end;
    if v_unit_cost <= 0 and v_book_id is not null then
      select greatest(0, coalesce(b.cost_price,0)) into v_unit_cost from public.books b where b.id = v_book_id;
    end if;
    if coalesce(v_unit_cost,0) <= 0 and v_telegram_book_id is not null then
      select greatest(0, coalesce(b.cost_price,0)) into v_unit_cost from public.books b where b.telegram_id = v_telegram_book_id;
    end if;
    v_unit_cost := coalesce(v_unit_cost,0);

    for unit_pos in 1..qty loop
      insert into public.sales_log(
        order_id, item_index, unit_index, book_id, telegram_book_id,
        title, source, unit_price, unit_cost, sold_at
      ) values (
        o.id, item_pos, unit_pos, v_book_id, v_telegram_book_id,
        v_title,
        case when o.source in ('app','telegram','instagram') then o.source else 'app' end,
        v_unit_price, v_unit_cost, v_sold_at
      );
    end loop;
  end loop;
end;
$function$;


CREATE OR REPLACE FUNCTION private.finance_report(p_period text DEFAULT 'month'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_period text := lower(trim(coalesce(p_period,'month')));
  v_start_ts timestamptz;
  v_start_date date;
  v_books_revenue bigint := 0;
  v_delivery_revenue bigint := 0;
  v_cost_of_goods bigint := 0;
  v_sold_books bigint := 0;
  v_orders bigint := 0;
  v_postage bigint := 0;
  v_postage_covered bigint := 0;
  v_store_postage bigint := 0;
  v_other_expenses bigint := 0;
  v_inventory_purchases bigint := 0;
  v_book_profit bigint := 0;
  v_operating_profit bigint := 0;
  v_cash_result bigint := 0;
  v_total_revenue bigint := 0;
  v_margin numeric := 0;
  v_sources jsonb := '{}'::jsonb;
  v_estimated_days bigint := 0;
begin
  if v_period not in ('today','week','month','all') then v_period := 'month'; end if;

  if v_period = 'today' then
    v_start_ts := date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date := (now() at time zone 'Asia/Seoul')::date;
  elsif v_period = 'week' then
    v_start_ts := date_trunc('week', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date := date_trunc('week', now() at time zone 'Asia/Seoul')::date;
  elsif v_period = 'month' then
    v_start_ts := date_trunc('month', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date := date_trunc('month', now() at time zone 'Asia/Seoul')::date;
  else
    v_start_ts := null;
    v_start_date := null;
  end if;

  select coalesce(sum(s.unit_price),0), coalesce(sum(s.unit_cost),0), count(*)
    into v_books_revenue, v_cost_of_goods, v_sold_books
  from public.sales_log s
  where v_start_ts is null or s.sold_at >= v_start_ts;

  select coalesce(sum(o.delivery_fee),0), count(*) filter (where o.status = 'shipping')
    into v_delivery_revenue, v_orders
  from public.orders o
  where (o.status = 'shipping' or
      (coalesce(o.source, 'app') in ('app', 'telegram') and o.status in ('accepted', 'paid')))
    and exists (
      select 1 from public.sales_log s
      where s.order_id = o.id
        and (v_start_ts is null or s.sold_at >= v_start_ts)
    );

  with shipped_by_day as (
    select (min(s.sold_at) at time zone 'Asia/Seoul')::date as day, o.id
    from public.orders o
    join public.sales_log s on s.order_id = o.id
    where (o.status = 'shipping' or
      (coalesce(o.source, 'app') in ('app', 'telegram') and o.status in ('accepted', 'paid')))
      and (v_start_ts is null or s.sold_at >= v_start_ts)
    group by o.id
  ), orders_per_day as (
    select day, count(*)::bigint as order_count from shipped_by_day group by day
  ), manual_postage as (
    select e.expense_date as day, sum(e.amount)::bigint as amount
    from public.finance_expenses e
    where e.category = 'postage'
      and (v_start_date is null or e.expense_date >= v_start_date)
    group by e.expense_date
  ), all_days as (
    select day from orders_per_day union select day from manual_postage
  )
  select
    coalesce(sum(case when mp.amount is not null then mp.amount else coalesce(opd.order_count,0) * 4000 end),0),
    coalesce(count(*) filter (where opd.order_count > 0 and mp.amount is null),0)
  into v_postage, v_estimated_days
  from all_days d
  left join orders_per_day opd using(day)
  left join manual_postage mp using(day);

  select coalesce(sum(e.amount),0)
    into v_inventory_purchases
  from public.finance_expenses e
  where e.category = 'inventory_purchase'
    and (v_start_date is null or e.expense_date >= v_start_date);

  select coalesce(sum(e.amount),0)
    into v_other_expenses
  from public.finance_expenses e
  where e.category not in ('postage','inventory_purchase')
    and (v_start_date is null or e.expense_date >= v_start_date);

  -- Mijoz to‘lagan yetkazish puli pochta xarajatini qoplaydi.
  -- Faqat do‘kon zimmasida qolgan pochta qismi foyda/zararni kamaytiradi.
  v_postage_covered := least(v_postage, v_delivery_revenue);
  v_store_postage := greatest(v_postage - v_postage_covered, 0);

  v_book_profit := v_books_revenue - v_cost_of_goods;
  v_operating_profit := v_book_profit - v_store_postage - v_other_expenses;

  -- Kassa natijasi: mijozning pochta puli alohida foyda hisoblanmaydi;
  -- u faqat pochta xarajatini qoplash uchun ishlatiladi.
  v_cash_result := v_books_revenue - v_inventory_purchases - v_store_postage - v_other_expenses;
  v_total_revenue := v_books_revenue + v_delivery_revenue;

  -- Marja sotilgan kitoblar bo‘yicha hisoblanadi. Yangi partiya xaridi
  -- hali sotilmagan zaxira bo‘lgani uchun savdo marjasini buzmaydi.
  if v_books_revenue > 0 then
    v_margin := round((v_operating_profit::numeric / v_books_revenue::numeric) * 100, 1);
  end if;

  select coalesce(jsonb_object_agg(x.source, x.amount), '{}'::jsonb)
    into v_sources
  from (
    select s.source, coalesce(sum(s.unit_price),0)::bigint as amount
    from public.sales_log s
    where v_start_ts is null or s.sold_at >= v_start_ts
    group by s.source
  ) x;

  return jsonb_build_object(
    'period', v_period,
    'books_revenue', v_books_revenue,
    'delivery_revenue', v_delivery_revenue,
    'total_revenue', v_total_revenue,
    'cost_of_goods', v_cost_of_goods,
    'book_profit', v_book_profit,
    'postage_expense', v_postage,
    'postage_covered_by_customers', v_postage_covered,
    'store_postage_expense', v_store_postage,
    'postage_is_estimated', (v_estimated_days > 0),
    'postage_estimated_days', v_estimated_days,
    'other_expenses', v_other_expenses,
    'inventory_purchases', v_inventory_purchases,
    'cash_outflow_total', v_inventory_purchases + v_store_postage + v_other_expenses,
    'total_expenses', v_inventory_purchases + v_store_postage + v_other_expenses,
    'operating_profit', v_operating_profit,
    'cash_result', v_cash_result,
    'net_profit', v_cash_result,
    'margin_percent', v_margin,
    'operating_margin_percent', v_margin,
    'sold_books', v_sold_books,
    'shipped_orders', v_orders,
    'source_book_revenue', v_sources
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public._order_set_status_core(p_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  o public.orders%rowtype;
  item jsonb;
  bid uuid;
  qty integer;
  b public.books%rowtype;
  needs_reserve boolean;
begin
  if p_status not in ('new','accepted','paid','shipping','cancelled') then raise exception 'Noto‘g‘ri holat'; end if;
  select * into o from public.orders where id = p_id for update;
  if not found then raise exception 'Buyurtma topilmadi'; end if;
  if o.status = 'cancelled' and p_status <> 'cancelled' then raise exception 'Bekor qilingan buyurtmani qayta faollashtirib bo‘lmaydi'; end if;
  if o.status = 'shipping' and p_status <> 'shipping' then raise exception 'Jo‘natilgan buyurtma yakuniy holatda'; end if;

  needs_reserve := p_status in ('new','accepted','paid','shipping') and not o.stock_reserved;
  if needs_reserve then
    for item in select * from jsonb_array_elements(o.items)
    loop
      bid := (item->>'book_id')::uuid;
      qty := greatest(coalesce((item->>'quantity')::integer, 0), 0);
      if qty <= 0 then raise exception 'Buyurtma tarkibi noto‘g‘ri'; end if;
      select * into b from public.books where id = bid for update;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi'; end if;
      if b.stock < qty then raise exception '“%” uchun omborda % dona kerak, % dona bor', b.title, qty, b.stock; end if;
    end loop;
    for item in select * from jsonb_array_elements(o.items)
    loop
      bid := (item->>'book_id')::uuid;
      qty := (item->>'quantity')::integer;
      update public.books set stock = stock - qty where id = bid;
    end loop;
    update public.orders set status=p_status, stock_reserved=true, stock_restored=false where id=p_id;
    return;
  end if;

  if p_status = 'cancelled' and o.status <> 'cancelled' then
    if o.stock_reserved and not o.stock_restored then
      for item in select * from jsonb_array_elements(o.items)
      loop
        bid := (item->>'book_id')::uuid;
        qty := greatest(coalesce((item->>'quantity')::integer, 0), 0);
        update public.books set stock = stock + qty where id = bid;
      end loop;
    end if;
    update public.orders set status='cancelled', stock_reserved=false, stock_restored=(o.stock_reserved or o.stock_restored) where id=p_id;
    return;
  end if;

  update public.orders set status=p_status where id=p_id;
end;
$function$;


CREATE OR REPLACE FUNCTION public.bot_order_create(p_secret text, p_order jsonb, p_preserve_stock boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tid bigint;
  v_chat bigint;
  v_id uuid;
  v_existing public.orders%rowtype;
  v_status text;
  item jsonb;
  kv record;
  b public.books%rowtype;
  qty integer;
  unit_price integer;
  safe_items jsonb := '[]'::jsonb;
  v_subtotal integer := 0;
  v_count integer := 0;
  v_fee integer := 4000;
  v_is_instagram boolean := false;
  v_created_at timestamptz;
  cutoff_ts timestamptz;
  cutoff_oid bigint;
begin
  if not public._secret_ok(p_secret, 'ff2c7a6de8f32fb3153d1f01a7e9b171005789f249f364bd5bc6bf2210c6adfd') then raise exception 'Ruxsat yo‘q'; end if;
  begin
    v_tid := nullif(p_order->>'order_id','')::bigint;
  exception when others then
    v_tid := null;
  end;
  if v_tid is null or v_tid <= 0 then raise exception 'Buyurtma raqami noto‘g‘ri'; end if;

  begin
    v_created_at := nullif(p_order->>'created_at','')::timestamptz;
  exception when others then
    v_created_at := now();
  end;
  v_created_at := coalesce(v_created_at, now());

  select reset_at, reset_order_id into cutoff_ts, cutoff_oid
  from public.system_reset_state where key='sales_orders';
  if cutoff_ts is not null and (v_created_at < cutoff_ts or v_tid < coalesce(cutoff_oid,0)) then
    raise exception 'Resetdan oldingi sinov buyurtmasi qabul qilinmaydi';
  end if;

  select * into v_existing from public.orders where telegram_order_id = v_tid;
  if found then
    return (select jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'stocks', (select coalesce(jsonb_object_agg(coalesce(b.telegram_id::text,b.id::text),b.stock),'{}'::jsonb) from public.books b where b.id in (select (x->>'book_id')::uuid from jsonb_array_elements(o.items) x))) from public.orders o where o.id=v_existing.id);
  end if;

  begin
    v_chat := nullif(p_order->>'chat_id','')::bigint;
  exception when others then
    v_chat := null;
  end;

  v_is_instagram := lower(coalesce(p_order->>'source','')) = 'instagram';

  if jsonb_typeof(p_order->'items')='array' and jsonb_array_length(p_order->'items')>0 then
    for item in select * from jsonb_array_elements(p_order->'items')
    loop
      begin
        select * into b from public.books where telegram_id=(item->>'book_id')::bigint and is_active=true;
      exception when others then
        raise exception 'Buyurtmadagi kitob IDsi noto‘g‘ri';
      end;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi: %', item->>'book_id'; end if;
      begin
        qty := greatest(1,coalesce(nullif(item->>'qty','')::integer,nullif(item->>'quantity','')::integer,1));
      exception when others then
        raise exception 'Kitob soni noto‘g‘ri';
      end;
      if qty > 100 then raise exception 'Bitta kitobdan juda ko‘p miqdor kiritildi'; end if;
      begin
        unit_price := greatest(0,coalesce(nullif(item->>'unit_price','')::integer,nullif(item->>'price','')::integer,round(b.price*(100-greatest(0,least(99,b.discount_percent)))/100.0)::integer));
      exception when others then
        unit_price := round(b.price*(100-greatest(0,least(99,b.discount_percent)))/100.0)::integer;
      end;
      v_subtotal := v_subtotal + unit_price * qty;
      v_count := v_count + qty;
      safe_items := safe_items || jsonb_build_array(jsonb_build_object(
        'book_id',b.id,'telegram_book_id',b.telegram_id,'title',b.title,'quantity',qty,
        'price',unit_price,'unit_price',unit_price,'line_total',unit_price*qty
      ));
    end loop;
  elsif jsonb_typeof(p_order->'cart')='object' then
    for kv in select * from jsonb_each_text(p_order->'cart')
    loop
      begin
        select * into b from public.books where telegram_id=kv.key::bigint and is_active=true;
      exception when others then
        raise exception 'Buyurtmadagi kitob IDsi noto‘g‘ri';
      end;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi: %', kv.key; end if;
      begin
        qty := greatest(1,kv.value::integer);
      exception when others then
        raise exception 'Kitob soni noto‘g‘ri';
      end;
      if qty > 100 then raise exception 'Bitta kitobdan juda ko‘p miqdor kiritildi'; end if;
      unit_price := round(b.price*(100-greatest(0,least(99,b.discount_percent)))/100.0)::integer;
      v_subtotal := v_subtotal + unit_price * qty;
      v_count := v_count + qty;
      safe_items := safe_items || jsonb_build_array(jsonb_build_object(
        'book_id',b.id,'telegram_book_id',b.telegram_id,'title',b.title,'quantity',qty,
        'price',unit_price,'unit_price',unit_price,'line_total',unit_price*qty
      ));
    end loop;
  end if;

  if jsonb_array_length(safe_items)=0 then raise exception 'Buyurtma savatchasi bo‘sh'; end if;

  -- Telegram buyurtmasida yetkazish qoidasi serverda qat'iy: 4+ kitob bepul.
  -- Instagram savdosida admin real tushum tarkibiga qarab 0 yoki 4000 ni tanlaydi.
  if v_is_instagram and p_preserve_stock then
    begin
      v_fee := case when coalesce((p_order->>'delivery_fee')::integer,0) >= 4000 then 4000 else 0 end;
    exception when others then
      v_fee := 0;
    end;
  else
    v_fee := case when v_count >= 4 then 0 else 4000 end;
  end if;

  insert into public.orders(
    customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,items,source,
    order_number,telegram_order_id,telegram_chat_id,telegram_username,
    telegram_receipt_file_id,payment_submitted_at,created_at
  ) values(
    coalesce(nullif(trim(p_order->>'name'),''),'Telegram mijoz'),
    coalesce(nullif(trim(p_order->>'phone'),''),'00000000'),
    coalesce(nullif(trim(p_order->>'address'),''),'Manzil ko‘rsatilmagan'),
    '택배',v_fee,v_subtotal,v_subtotal+v_fee,safe_items,'telegram',
    v_tid,v_tid,v_chat,coalesce(p_order->>'username',''),
    coalesce(p_order->>'receipt_file_id',''),now(),v_created_at
  ) returning id into v_id;

  if p_preserve_stock and coalesce(p_order->>'status','pending') not in ('pending','new') then
    v_status := case coalesce(p_order->>'status','pending')
      when 'accepted' then 'accepted'
      when 'paid' then 'paid'
      when 'shipped' then 'shipping'
      when 'delivered' then 'shipping'
      when 'done' then 'shipping'
      when 'cancelled' then 'cancelled'
      else 'new'
    end;
    -- Bot katalogida qoldiq allaqachon kamaygan bo‘lsa, bu yerda qayta ayirmaymiz.
    -- Faqat holat/rezerv bayrog‘ini aks ettiramiz; trigger sotuv tarixini yaratadi.
    update public.orders
       set status = v_status,
           stock_reserved = (v_status in ('accepted','paid','shipping')),
           stock_restored = false
     where id = v_id;
  else
    -- A new Telegram order reserves stock before admin review, including retries.
    perform public._order_set_status_core(v_id, 'new');
  end if;

  return (select jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'stocks', (select coalesce(jsonb_object_agg(coalesce(b.telegram_id::text,b.id::text),b.stock),'{}'::jsonb) from public.books b where b.id in (select (x->>'book_id')::uuid from jsonb_array_elements(o.items) x))) from public.orders o where o.id=v_id);
end;
$function$;

-- Recognize already accepted Telegram orders without touching their stock.
do $backfill$
declare r record;
begin
  for r in select id from public.orders
    where source='telegram' and status in ('accepted','paid')
  loop
    perform public._rebuild_sales_log_for_order(r.id);
  end loop;
  for r in select id from public.orders
    where source in ('app','telegram') and status='new'
      and not stock_reserved and not stock_restored
  loop
    perform public._order_set_status_core(r.id,'new');
  end loop;
end;
$backfill$;
