-- Muhajeer Books sales/inventory analytics (additive, no changes to old data).
-- Tracking begins when this migration is applied. Earlier stock histories are not invented.
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check(length(trim(name)) between 2 and 200),
  country text not null default '',
  contact text not null default '',
  created_at timestamptz not null default now()
);
alter table public.suppliers enable row level security;
revoke all on public.suppliers from anon, authenticated;

alter table public.web_book_batches
  add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.web_book_batches
  add column if not exists received_at timestamptz;

create table if not exists public.inventory_movements (
  id bigint generated always as identity primary key,
  book_id uuid not null,
  book_title text not null,
  quantity_change integer not null,
  stock_after integer not null check (stock_after >= 0),
  movement_type text not null check (movement_type in ('created','increase','decrease')),
  happened_at timestamptz not null default now()
);
create index if not exists inventory_movements_book_time
 on public.inventory_movements(book_id,happened_at desc);
alter table public.inventory_movements enable row level security;
revoke all on public.inventory_movements from anon, authenticated;

create table if not exists public.stock_daily_snapshots (
  book_id uuid not null references public.books(id) on delete cascade,
  snapshot_date date not null,
  stock_quantity integer not null check(stock_quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key(book_id,snapshot_date)
);
alter table public.stock_daily_snapshots enable row level security;
revoke all on public.stock_daily_snapshots from anon, authenticated;

-- Current state is the *starting baseline*, not a fabricated historical balance.
insert into public.stock_daily_snapshots(book_id,snapshot_date,stock_quantity)
select id,(now() at time zone 'Asia/Seoul')::date,stock from public.books
on conflict(book_id,snapshot_date) do nothing;

create or replace function private.capture_inventory_analytics()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare v_delta integer;
begin
  if TG_OP = 'UPDATE' and new.stock = old.stock then
    return new;
  end if;
  v_delta := case when TG_OP='INSERT' then new.stock else new.stock-old.stock end;
  insert into public.inventory_movements(book_id,book_title,quantity_change,stock_after,movement_type)
  values(new.id,new.title,v_delta,new.stock,
    case when TG_OP='INSERT' then 'created' when v_delta>0 then 'increase' else 'decrease' end);
  insert into public.stock_daily_snapshots(book_id,snapshot_date,stock_quantity,updated_at)
  values(new.id,(now() at time zone 'Asia/Seoul')::date,new.stock,now())
  on conflict(book_id,snapshot_date) do update
    set stock_quantity=excluded.stock_quantity,updated_at=excluded.updated_at;
  return new;
end;
$fn$;
drop trigger if exists books_capture_inventory_analytics on public.books;
create trigger books_capture_inventory_analytics
after insert or update of stock on public.books
for each row execute function private.capture_inventory_analytics();

-- Admin reporting is read-only. No exposure of costs to public client roles.
create or replace function public.admin_sales_inventory_analytics(
  p_secret text, p_days integer default 30, p_source text default 'all'
) returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_from date;
  v_summary jsonb;
  v_books jsonb;
  v_channels jsonb;
  v_genres jsonb;
  v_daily jsonb;
  v_suppliers jsonb;
  v_batches jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_days not in (30,365) then
    raise exception 'Davr faqat 30 yoki 365 kun bo‘lishi mumkin';
  end if;
  if p_source not in ('all','app','instagram','telegram','sms','phone','in_person') then
    raise exception 'Sotuv kanali noto‘g‘ri';
  end if;
  v_from := v_today-p_days+1;

  with selected as (
    select s.book_id,s.source,s.unit_price,s.sold_at,
       coalesce(ps.unit_cost,s.unit_cost) unit_cost,
       coalesce(ps.cost_known,s.unit_cost>0) cost_known
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date between v_from and v_today
      and (p_source='all' or s.source=p_source)
  )
  select jsonb_build_object(
    'catalog_books',(select count(*) from public.books),
    'total_stock',(select coalesce(sum(stock),0) from public.books),
    'low_stock',(select count(*) from public.books where stock between 1 and 2),
    'out_of_stock',(select count(*) from public.books where stock=0),
    'sold_units',count(*),
    'revenue',coalesce(sum(unit_price),0),
    'profit',coalesce(sum(unit_price-unit_cost) filter(where cost_known),0),
    'unlinked_units',count(*) filter(where book_id is null),
    'unknown_cost_units',count(*) filter(where not cost_known)
  ) into v_summary from selected;

  with selected as (
    select s.book_id,s.unit_price,
       coalesce(ps.unit_cost,s.unit_cost) unit_cost,
       coalesce(ps.cost_known,s.unit_cost>0) cost_known
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date between v_from and v_today
      and (p_source='all' or s.source=p_source)
  ), by_book as (
    select book_id,count(*)::integer sold,
      sum(unit_price)::bigint revenue,
      sum(unit_price-unit_cost) filter(where cost_known)::bigint profit
    from selected group by book_id
  ), days as (
    select d::date as snapshot_day from generate_series(v_from,v_today,interval '1 day') d
  ), stock_stats as (
    select b.id, count(snap.stock_quantity)::integer coverage_days,
      round(avg(snap.stock_quantity),2) avg_stock
    from public.books b cross join days d
    left join lateral (
      select q.stock_quantity from public.stock_daily_snapshots q
      where q.book_id=b.id and q.snapshot_date <= d.snapshot_day
      order by q.snapshot_date desc limit 1
    ) snap on true
    group by b.id
  ), details as (
    select b.id,b.title,b.author,b.category,b.stock,b.price,b.cost_price,
      coalesce(s.sold,0) sold,coalesce(s.revenue,0) revenue,coalesce(s.profit,0) profit,
      coalesce(st.coverage_days,0) coverage_days,st.avg_stock,
      case when st.coverage_days = p_days and st.avg_stock>0
           then round(coalesce(s.sold,0)::numeric / st.avg_stock,2)
           else null end turnover
    from public.books b
    left join by_book s on s.book_id=b.id
    left join stock_stats st on st.id=b.id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',id,'title',title,'author',author,'category',category,
      'stock',stock,'price',price,'cost_price',cost_price,'sold',sold,
      'revenue',revenue,'profit',profit,'avg_stock',avg_stock,
      'coverage_days',coverage_days,'turnover',turnover,
      'recommendation',case when turnover is null then 'history_pending'
         when turnover>=2 then 'restock' when turnover<0.5 and stock>0 then 'slow'
         else 'watch' end
     ) order by sold desc,title),'[]'::jsonb)
   into v_books from details;

  with selected as (
    select s.source,s.unit_price
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date between v_from and v_today
      and (p_source='all' or s.source=p_source)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'source',source,'sold',sold,'revenue',revenue) order by sold desc),'[]'::jsonb)
  into v_channels from (
    select source,count(*) sold,sum(unit_price)::bigint revenue
    from selected group by source
  ) c;

  with selected as (
    select coalesce(nullif(trim(b.category),''),'Boshqalar') category,
      s.unit_price,coalesce(ps.unit_cost,s.unit_cost) unit_cost,
      coalesce(ps.cost_known,s.unit_cost>0) cost_known
    from public.sales_log s
    left join public.books b on b.id=s.book_id
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date between v_from and v_today
      and (p_source='all' or s.source=p_source)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
     'category',category,'sold',sold,'revenue',revenue,'profit',profit,
     'stock_value',(select coalesce(sum(b.stock::bigint*b.cost_price),0) from public.books b
       where coalesce(nullif(trim(b.category),''),'Boshqalar')=g.category))
      order by sold desc),'[]'::jsonb)
  into v_genres from (
    select category,count(*) sold,sum(unit_price)::bigint revenue,
      coalesce(sum(unit_price-unit_cost) filter(where cost_known),0)::bigint profit
    from selected group by category
  ) g;

  with day_totals as (
    select (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date as sale_day,
      count(*) sold,sum(s.unit_price)::bigint revenue
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date between v_from and v_today
      and (p_source='all' or s.source=p_source)
    group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object('day',d::date,
    'sold',coalesce(t.sold,0),'revenue',coalesce(t.revenue,0))
    order by d),'[]'::jsonb)
  into v_daily from generate_series(v_from,v_today,interval '1 day') d
  left join day_totals t on t.sale_day=d::date;

  select coalesce(jsonb_agg(jsonb_build_object(
    'name',supplier_name,'units',units,'last_received',last_received)
    order by units desc),'[]'::jsonb)
  into v_suppliers from (
     select coalesce(s.name,'Yetkazib beruvchi ko‘rsatilmagan') supplier_name,
       sum(w.quantity)::bigint units,
       max(coalesce(w.received_at::date,w.purchased_at)) last_received
     from public.web_book_batches w
     left join public.suppliers s on s.id=w.supplier_id
     group by s.name
  ) x;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',w.id,'book_id',w.book_id,'book_title',b.title,'quantity',w.quantity,
    'purchased_at',w.purchased_at,'supplier_id',w.supplier_id,
    'supplier_name',su.name) order by w.purchased_at desc,w.id desc),'[]'::jsonb)
  into v_batches
  from public.web_book_batches w
  join public.books b on b.id=w.book_id
  left join public.suppliers su on su.id=w.supplier_id;
  return jsonb_build_object('days',p_days,'from',v_from,'to',v_today,
     'source',p_source,'summary',v_summary,'books',v_books,'channels',v_channels,
     'genres',v_genres,'daily',v_daily,'suppliers',v_suppliers,
     'batches',v_batches,'generated_at',now());
end;
$fn$;

-- Prevent public access except through the admin-secret verified RPC.
revoke all on function public.admin_sales_inventory_analytics(text,integer,text) from public;
grant execute on function public.admin_sales_inventory_analytics(text,integer,text)
  to anon,authenticated;

-- Idempotency protects against duplicate taps and connection retries.
create table if not exists public.offline_sale_requests (
  request_key text primary key,
  order_id uuid unique not null references public.orders(id) on delete restrict,
  created_at timestamptz not null default now()
);
alter table public.offline_sale_requests enable row level security;
revoke all on public.offline_sale_requests from anon,authenticated;

-- Extend the existing sales-log builder only to recognize SMS/phone sales.
-- Its existing order/status/cost behavior is otherwise unchanged.
create or replace function public._rebuild_sales_log_for_order(p_order_id uuid)
returns void language plpgsql security definer set search_path to 'public'
as $fn$
declare
  o public.orders%rowtype; item jsonb; item_pos integer; qty integer; unit_pos integer;
  v_book_id uuid; v_telegram_book_id bigint; v_title text;
  v_unit_price integer; v_unit_cost integer; v_sold_at timestamptz;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then return; end if;
  if not (o.status='shipping' or
    (coalesce(o.source,'app') in ('app','telegram','instagram','sms','phone','in_person')
     and o.status in ('accepted','paid'))) then
    delete from public.sales_log where order_id=o.id;
    return;
  end if;
  select min(sold_at) into v_sold_at from public.sales_log where order_id=o.id;
  v_sold_at:=coalesce(v_sold_at,o.created_at,o.updated_at,now());
  delete from public.sales_log where order_id=o.id;
  for item,item_pos in
    select value,ordinality::integer
    from jsonb_array_elements(coalesce(o.items,'[]'::jsonb)) with ordinality
  loop
    begin qty:=greatest(1,coalesce(nullif(item->>'quantity','')::integer,nullif(item->>'qty','')::integer,1));
    exception when others then qty:=1; end;
    begin v_book_id:=nullif(item->>'book_id','')::uuid;
    exception when others then v_book_id:=null; end;
    begin v_telegram_book_id:=nullif(item->>'telegram_book_id','')::bigint;
    exception when others then v_telegram_book_id:=null; end;
    if v_book_id is not null and not exists(select 1 from public.books b where b.id=v_book_id)
      then v_book_id:=null; end if;
    if v_book_id is null and v_telegram_book_id is not null then
      select b.id into v_book_id from public.books b
      where b.telegram_id=v_telegram_book_id limit 1;
    end if;
    v_title:=coalesce(nullif(trim(item->>'title'),''),nullif(trim(item->>'name'),''),'Kitob');
    begin v_unit_price:=greatest(0,coalesce(nullif(item->>'unit_price','')::integer,nullif(item->>'price','')::integer,0));
    exception when others then v_unit_price:=0; end;
    begin v_unit_cost:=greatest(0,coalesce(nullif(item->>'unit_cost','')::integer,0));
    exception when others then v_unit_cost:=0; end;
    if v_unit_cost<=0 and v_book_id is not null then
      select greatest(0,coalesce(b.cost_price,0)) into v_unit_cost
      from public.books b where b.id=v_book_id;
    end if;
    v_unit_cost:=coalesce(v_unit_cost,0);
    for unit_pos in 1..qty loop
      insert into public.sales_log(order_id,item_index,unit_index,book_id,
        telegram_book_id,title,source,unit_price,unit_cost,sold_at)
      values(o.id,item_pos,unit_pos,v_book_id,v_telegram_book_id,v_title,
        case when o.source in ('app','telegram','instagram','sms','phone','in_person')
          then o.source else 'app' end,
        v_unit_price,v_unit_cost,v_sold_at);
    end loop;
  end loop;
end;
$fn$;

create or replace function public.admin_record_offline_sale(
  p_secret text,p_channel text,p_items jsonb,p_customer_name text,
  p_phone text,p_note text,p_request_key text
) returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare
  v_existing uuid;
  v_order uuid;
  v_items jsonb := '[]'::jsonb;
  v_total bigint := 0;
  rec record;
  v_book public.books%rowtype;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_channel not in ('instagram','telegram','sms','phone','in_person') then
    raise exception 'Sotuv manbasi noto‘g‘ri';
  end if;
  if p_request_key is null or length(p_request_key) not between 16 and 128
    or p_request_key !~ '^[a-zA-Z0-9._:-]+$' then
    raise exception 'Takroriy sotuvdan himoya kaliti noto‘g‘ri';
  end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 30 then
    raise exception 'Sotuv tarkibi noto‘g‘ri';
  end if;
  -- Retry with the same key returns the original order; no second stock decrement.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_key,0));
  select order_id into v_existing
    from public.offline_sale_requests where request_key=p_request_key;
  if found then return jsonb_build_object('order_id',v_existing,'duplicate',true); end if;
  for rec in
    select (x->>'book_id')::uuid book_id,
      sum((x->>'quantity')::integer)::integer quantity,
      min((x->>'unit_price')::integer)::integer unit_price,
      max((x->>'unit_price')::integer)::integer max_price
    from jsonb_array_elements(p_items) x
    group by (x->>'book_id')::uuid
    order by (x->>'book_id')::uuid
  loop
    if rec.quantity not between 1 and 100 or rec.unit_price<>rec.max_price
       or rec.unit_price<0 or rec.unit_price>100000000 then
      raise exception 'Kitob miqdori yoki narxi noto‘g‘ri';
    end if;
    select * into v_book from public.books where id=rec.book_id and is_active for update;
    if not found then raise exception 'Kitob topilmadi yoki faol emas'; end if;
    if v_book.stock<rec.quantity then
      raise exception '“%” omborda yetarli emas. Qoldiq: % dona',
        v_book.title,v_book.stock;
    end if;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'book_id',v_book.id,'telegram_book_id',v_book.telegram_id,'title',v_book.title,
      'quantity',rec.quantity,'unit_price',rec.unit_price,'price',rec.unit_price,
      'unit_cost',v_book.cost_price,'line_total',rec.unit_price*rec.quantity));
    v_total := v_total + rec.unit_price::bigint*rec.quantity;
    if v_total>1000000000 then raise exception 'Sotuv summasi juda katta'; end if;
  end loop;
  -- Non-app insert bypasses the existing app-only stock-reservation trigger.
  -- All stock changes and order insertion still occur in one SQL transaction.
  insert into public.orders(
    customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,
    status,items,source,stock_reserved,stock_restored,entered_by_admin,
    payment_status,order_note
  ) values (
    coalesce(nullif(trim(p_customer_name),''),'Oflayn mijoz'),
    coalesce(nullif(trim(p_phone),''),'00000000'),
    'Oflayn savdo','pickup',0,v_total::integer,v_total::integer,
    'accepted',v_items,p_channel,true,false,true,'paid',coalesce(p_note,'')
  ) returning id into v_order;
  for rec in
    select (x->>'book_id')::uuid book_id,(x->>'quantity')::integer quantity
    from jsonb_array_elements(v_items) x
  loop
    update public.books set stock=stock-rec.quantity where id=rec.book_id;
  end loop;
  insert into public.offline_sale_requests(request_key,order_id)
   values(p_request_key,v_order);
  return jsonb_build_object('order_id',v_order,'duplicate',false);
end;
$fn$;
revoke all on function public.admin_record_offline_sale(text,text,jsonb,text,text,text,text) from public;
grant execute on function public.admin_record_offline_sale(text,text,jsonb,text,text,text,text)
  to anon,authenticated;


-- Supplier creation and linking to exact purchase-batch lines.
create or replace function public.admin_manage_inventory_supplier(
  p_secret text,p_action text,p_supplier_id uuid default null,
  p_name text default null,p_country text default '',
  p_contact text default '',p_batch_id bigint default null
) returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare
  v_id uuid;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_action='save' then
    if length(trim(coalesce(p_name,''))) not between 2 and 200 then
      raise exception 'Yetkazib beruvchi nomi noto‘g‘ri';
    end if;
    if p_supplier_id is null then
      insert into public.suppliers(name,country,contact)
        values(trim(p_name),left(coalesce(p_country,''),120),left(coalesce(p_contact,''),200))
        returning id into v_id;
    else
      update public.suppliers
      set name=trim(p_name),country=left(coalesce(p_country,''),120),
        contact=left(coalesce(p_contact,''),200)
      where id=p_supplier_id returning id into v_id;
      if v_id is null then raise exception 'Yetkazib beruvchi topilmadi'; end if;
    end if;
    return jsonb_build_object('ok',true,'supplier_id',v_id);
  elsif p_action='assign' then
    if p_batch_id is null then raise exception 'Partiya qatori tanlanmagan'; end if;
    if p_supplier_id is not null and
      not exists(select 1 from public.suppliers where id=p_supplier_id)
    then raise exception 'Yetkazib beruvchi topilmadi'; end if;
    update public.web_book_batches
      set supplier_id=p_supplier_id where id=p_batch_id;
    if not found then raise exception 'Partiya qatori topilmadi'; end if;
    return jsonb_build_object('ok',true,'batch_id',p_batch_id);
  else
    raise exception 'Amal noto‘g‘ri';
  end if;
end;
$fn$;
revoke all on function public.admin_manage_inventory_supplier(text,text,uuid,text,text,text,bigint) from public;
grant execute on function public.admin_manage_inventory_supplier(text,text,uuid,text,text,text,bigint)
  to anon,authenticated;
