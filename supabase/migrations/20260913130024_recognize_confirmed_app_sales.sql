-- App sales enter the existing ledger at admin acceptance, before dispatch.
-- Pending/new and cancelled orders remain excluded; stock and order status are untouched.
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
      (coalesce(o.source, 'app') = 'app' and o.status in ('accepted', 'paid'))) then
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
$function$
;
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
      (coalesce(o.source, 'app') = 'app' and o.status in ('accepted', 'paid')))
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
      (coalesce(o.source, 'app') = 'app' and o.status in ('accepted', 'paid')))
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
$function$
;
revoke execute on function public._rebuild_sales_log_for_order(uuid) from public, anon, authenticated;
revoke execute on function private.finance_report(text) from public, anon, authenticated;

-- Recover missing confirmed app sales without rebuilding any existing history.
do $backfill$
declare r record;
  v_stock_before text;
  v_stock_after text;
begin
  select md5(string_agg(id::text || ':' || stock::text, ',' order by id)) into v_stock_before from public.books;
  for r in select o.id from public.orders o
    where coalesce(o.source, 'app') = 'app'
      and o.status in ('accepted', 'paid', 'shipping')
      and not exists (select 1 from public.sales_log s where s.order_id = o.id)
  loop
    perform public._rebuild_sales_log_for_order(r.id);
  end loop;
  select md5(string_agg(id::text || ':' || stock::text, ',' order by id)) into v_stock_after from public.books;
  if v_stock_before is distinct from v_stock_after then
    raise exception 'Sales recovery must not change stock';
  end if;
end;
$backfill$;
