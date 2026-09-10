-- Unified Muhajeer Books finance ledger for web/APK and Telegram.
-- Direct table access stays closed; admin/bot use existing secret-guarded RPCs.

create table if not exists public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default ((now() at time zone 'Asia/Seoul')::date),
  category text not null,
  amount integer not null check (amount > 0),
  note text not null default '',
  source text not null default 'admin',
  created_at timestamptz not null default now(),
  constraint finance_expenses_category_check check (category in ('postage','packaging','ads','transport','other')),
  constraint finance_expenses_source_check check (source in ('admin','telegram','import'))
);

alter table public.finance_expenses enable row level security;
revoke all on table public.finance_expenses from public, anon, authenticated;
create index if not exists finance_expenses_date_idx on public.finance_expenses(expense_date desc, created_at desc);
create index if not exists finance_expenses_category_idx on public.finance_expenses(category, expense_date desc);

alter table public.sales_log add column if not exists unit_cost integer not null default 0;

create or replace function private.snapshot_order_unit_cost()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item jsonb;
  safe_items jsonb := '[]'::jsonb;
  v_book_id uuid;
  v_telegram_book_id bigint;
  v_cost integer := 0;
begin
  if jsonb_typeof(new.items) <> 'array' then return new; end if;
  for item in select value from jsonb_array_elements(new.items) loop
    v_book_id := null; v_telegram_book_id := null; v_cost := 0;
    begin v_book_id := nullif(item->>'book_id','')::uuid; exception when others then v_book_id := null; end;
    begin v_telegram_book_id := nullif(item->>'telegram_book_id','')::bigint; exception when others then v_telegram_book_id := null; end;
    if v_book_id is not null then
      select greatest(0,coalesce(b.cost_price,0)) into v_cost from public.books b where b.id=v_book_id;
    elsif v_telegram_book_id is not null then
      select greatest(0,coalesce(b.cost_price,0)) into v_cost from public.books b where b.telegram_id=v_telegram_book_id;
    end if;
    safe_items := safe_items || jsonb_build_array(item || jsonb_build_object('unit_cost',coalesce(v_cost,0)));
  end loop;
  new.items := safe_items;
  return new;
end;
$$;
revoke execute on function private.snapshot_order_unit_cost() from public, anon, authenticated;
drop trigger if exists zzy_orders_snapshot_unit_cost on public.orders;
create trigger zzy_orders_snapshot_unit_cost before insert on public.orders for each row execute function private.snapshot_order_unit_cost();

create or replace function public._rebuild_sales_log_for_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path='public'
as $$
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
  select * into o from public.orders where id=p_order_id;
  if not found then return; end if;
  if o.status <> 'shipping' then delete from public.sales_log where order_id=o.id; return; end if;
  select min(sold_at) into v_sold_at from public.sales_log where order_id=o.id;
  v_sold_at := coalesce(v_sold_at,now());
  delete from public.sales_log where order_id=o.id;
  for item,item_pos in select value,ordinality::integer from jsonb_array_elements(coalesce(o.items,'[]'::jsonb)) with ordinality loop
    begin qty:=greatest(1,coalesce(nullif(item->>'quantity','')::integer,nullif(item->>'qty','')::integer,1)); exception when others then qty:=1; end;
    begin v_book_id:=nullif(item->>'book_id','')::uuid; exception when others then v_book_id:=null; end;
    begin v_telegram_book_id:=nullif(item->>'telegram_book_id','')::bigint; exception when others then v_telegram_book_id:=null; end;
    v_title:=coalesce(nullif(trim(item->>'title'),''),nullif(trim(item->>'name'),''),'Kitob');
    begin v_unit_price:=greatest(0,coalesce(nullif(item->>'unit_price','')::integer,nullif(item->>'price','')::integer,0)); exception when others then v_unit_price:=0; end;
    begin v_unit_cost:=greatest(0,coalesce(nullif(item->>'unit_cost','')::integer,0)); exception when others then v_unit_cost:=0; end;
    if v_unit_cost<=0 and v_book_id is not null then select greatest(0,coalesce(b.cost_price,0)) into v_unit_cost from public.books b where b.id=v_book_id; end if;
    if coalesce(v_unit_cost,0)<=0 and v_telegram_book_id is not null then select greatest(0,coalesce(b.cost_price,0)) into v_unit_cost from public.books b where b.telegram_id=v_telegram_book_id; end if;
    v_unit_cost:=coalesce(v_unit_cost,0);
    for unit_pos in 1..qty loop
      insert into public.sales_log(order_id,item_index,unit_index,book_id,telegram_book_id,title,source,unit_price,unit_cost,sold_at)
      values(o.id,item_pos,unit_pos,v_book_id,v_telegram_book_id,v_title,case when o.source in ('app','telegram','instagram') then o.source else 'app' end,v_unit_price,v_unit_cost,v_sold_at);
    end loop;
  end loop;
end;
$$;
revoke execute on function public._rebuild_sales_log_for_order(uuid) from public,anon,authenticated;

create or replace function private.finance_report(p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_period text:=lower(trim(coalesce(p_period,'month')));
  v_start_ts timestamptz;
  v_start_date date;
  v_books_revenue bigint:=0;
  v_delivery_revenue bigint:=0;
  v_cost_of_goods bigint:=0;
  v_sold_books bigint:=0;
  v_orders bigint:=0;
  v_postage bigint:=0;
  v_other_expenses bigint:=0;
  v_book_profit bigint:=0;
  v_net_profit bigint:=0;
  v_total_revenue bigint:=0;
  v_margin numeric:=0;
  v_sources jsonb:='{}'::jsonb;
  v_estimated_days bigint:=0;
begin
  if v_period not in ('today','week','month','all') then v_period:='month'; end if;
  if v_period='today' then
    v_start_ts:=date_trunc('day',now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date:=(now() at time zone 'Asia/Seoul')::date;
  elsif v_period='week' then
    v_start_ts:=date_trunc('week',now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date:=date_trunc('week',now() at time zone 'Asia/Seoul')::date;
  elsif v_period='month' then
    v_start_ts:=date_trunc('month',now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';
    v_start_date:=date_trunc('month',now() at time zone 'Asia/Seoul')::date;
  else
    v_start_ts:=null; v_start_date:=null;
  end if;

  select coalesce(sum(s.unit_price),0),coalesce(sum(s.unit_cost),0),count(*)
  into v_books_revenue,v_cost_of_goods,v_sold_books
  from public.sales_log s where v_start_ts is null or s.sold_at>=v_start_ts;

  select coalesce(sum(o.delivery_fee),0),count(*) into v_delivery_revenue,v_orders
  from public.orders o where o.status='shipping'
    and exists(select 1 from public.sales_log s where s.order_id=o.id and (v_start_ts is null or s.sold_at>=v_start_ts));

  with shipped_by_day as (
    select (min(s.sold_at) at time zone 'Asia/Seoul')::date day,o.id
    from public.orders o join public.sales_log s on s.order_id=o.id
    where o.status='shipping' and (v_start_ts is null or s.sold_at>=v_start_ts)
    group by o.id
  ), orders_per_day as (
    select day,count(*)::bigint order_count from shipped_by_day group by day
  ), manual_postage as (
    select e.expense_date day,sum(e.amount)::bigint amount from public.finance_expenses e
    where e.category='postage' and (v_start_date is null or e.expense_date>=v_start_date)
    group by e.expense_date
  ), all_days as (
    select day from orders_per_day union select day from manual_postage
  )
  select coalesce(sum(case when mp.amount is not null then mp.amount else coalesce(opd.order_count,0)*4000 end),0),
         coalesce(count(*) filter(where opd.order_count>0 and mp.amount is null),0)
  into v_postage,v_estimated_days
  from all_days d left join orders_per_day opd using(day) left join manual_postage mp using(day);

  select coalesce(sum(e.amount),0) into v_other_expenses
  from public.finance_expenses e where e.category<>'postage' and (v_start_date is null or e.expense_date>=v_start_date);

  v_book_profit:=v_books_revenue-v_cost_of_goods;
  v_total_revenue:=v_books_revenue+v_delivery_revenue;
  v_net_profit:=v_total_revenue-v_cost_of_goods-v_postage-v_other_expenses;
  if v_total_revenue>0 then v_margin:=round((v_net_profit::numeric/v_total_revenue::numeric)*100,1); end if;
  select coalesce(jsonb_object_agg(x.source,x.amount),'{}'::jsonb) into v_sources from (
    select s.source,coalesce(sum(s.unit_price),0)::bigint amount
    from public.sales_log s where v_start_ts is null or s.sold_at>=v_start_ts group by s.source
  ) x;
  return jsonb_build_object('period',v_period,'books_revenue',v_books_revenue,'delivery_revenue',v_delivery_revenue,'total_revenue',v_total_revenue,'cost_of_goods',v_cost_of_goods,'book_profit',v_book_profit,'postage_expense',v_postage,'postage_is_estimated',(v_estimated_days>0),'postage_estimated_days',v_estimated_days,'other_expenses',v_other_expenses,'total_expenses',v_postage+v_other_expenses,'net_profit',v_net_profit,'margin_percent',v_margin,'sold_books',v_sold_books,'shipped_orders',v_orders,'source_book_revenue',v_sources);
end;
$$;
revoke execute on function private.finance_report(text) from public,anon,authenticated;

create or replace function public.admin_finance_report(p_secret text,p_period text default 'month') returns jsonb language plpgsql security definer set search_path='' as $$
begin if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if; return private.finance_report(p_period); end; $$;

-- Reuse bot_sales_list as the existing bot-secret verifier; no duplicate secret material here.
create or replace function public.bot_finance_report(p_secret text,p_period text default 'month') returns jsonb language plpgsql security definer set search_path='' as $$
begin perform 1 from public.bot_sales_list(p_secret,1) limit 1; return private.finance_report(p_period); end; $$;

create or replace function public.admin_add_finance_expense(p_secret text,p_amount integer,p_category text,p_note text default '',p_expense_date date default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_category text:=lower(trim(coalesce(p_category,''))); v_id uuid;
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Xarajat summasi noto‘g‘ri'; end if;
  if v_category not in ('postage','packaging','ads','transport','other') then raise exception 'Xarajat turi noto‘g‘ri'; end if;
  insert into public.finance_expenses(expense_date,category,amount,note,source) values(coalesce(p_expense_date,(now() at time zone 'Asia/Seoul')::date),v_category,p_amount,left(trim(coalesce(p_note,'')),300),'admin') returning id into v_id;
  return jsonb_build_object('id',v_id,'ok',true);
end; $$;

create or replace function public.bot_add_finance_expense(p_secret text,p_amount integer,p_category text default 'postage',p_note text default '',p_expense_date date default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_category text:=lower(trim(coalesce(p_category,'postage'))); v_id uuid;
begin
  perform 1 from public.bot_sales_list(p_secret,1) limit 1;
  if p_amount is null or p_amount<=0 then raise exception 'Xarajat summasi noto‘g‘ri'; end if;
  if v_category not in ('postage','packaging','ads','transport','other') then raise exception 'Xarajat turi noto‘g‘ri'; end if;
  insert into public.finance_expenses(expense_date,category,amount,note,source) values(coalesce(p_expense_date,(now() at time zone 'Asia/Seoul')::date),v_category,p_amount,left(trim(coalesce(p_note,'')),300),'telegram') returning id into v_id;
  return jsonb_build_object('id',v_id,'ok',true);
end; $$;

create or replace function public.admin_finance_expenses(p_secret text,p_limit integer default 100) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'expense_date',e.expense_date,'category',e.category,'amount',e.amount,'note',e.note,'source',e.source,'created_at',e.created_at) order by e.expense_date desc,e.created_at desc),'[]'::jsonb)
  into v_result from (select * from public.finance_expenses order by expense_date desc,created_at desc limit greatest(1,least(coalesce(p_limit,100),500))) e;
  return v_result;
end; $$;

create or replace function public.admin_delete_finance_expense(p_secret text,p_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if; delete from public.finance_expenses where id=p_id; return found; end; $$;

grant execute on function public.admin_finance_report(text,text) to anon,authenticated;
grant execute on function public.admin_add_finance_expense(text,integer,text,text,date) to anon,authenticated;
grant execute on function public.admin_finance_expenses(text,integer) to anon,authenticated;
grant execute on function public.admin_delete_finance_expense(text,uuid) to anon,authenticated;
grant execute on function public.bot_finance_report(text,text) to anon,authenticated;
grant execute on function public.bot_add_finance_expense(text,integer,text,text,date) to anon,authenticated;

do $$ declare r record; begin for r in select id from public.orders where status='shipping' loop perform public._rebuild_sales_log_for_order(r.id); end loop; end $$;
