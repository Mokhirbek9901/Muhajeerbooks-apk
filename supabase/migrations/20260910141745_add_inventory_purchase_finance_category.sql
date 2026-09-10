alter table public.finance_expenses drop constraint if exists finance_expenses_category_check;
alter table public.finance_expenses add constraint finance_expenses_category_check check (
  category = any (
    array[
      'postage'::text,
      'packaging'::text,
      'ads'::text,
      'transport'::text,
      'inventory_purchase'::text,
      'other'::text
    ]
  )
);

create or replace function public.admin_add_finance_expense(
  p_secret text,
  p_amount integer,
  p_category text,
  p_note text default ''::text,
  p_expense_date date default null::date
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_category text := lower(trim(coalesce(p_category,'')));
  v_id uuid;
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Xarajat summasi noto‘g‘ri';
  end if;
  if v_category not in (
    'postage','packaging','ads','transport','inventory_purchase','other'
  ) then
    raise exception 'Xarajat turi noto‘g‘ri';
  end if;

  insert into public.finance_expenses(
    expense_date, category, amount, note, source
  ) values (
    coalesce(p_expense_date,(now() at time zone 'Asia/Seoul')::date),
    v_category,
    p_amount,
    left(trim(coalesce(p_note,'')),300),
    'admin'
  ) returning id into v_id;

  return jsonb_build_object('id',v_id,'ok',true);
end;
$function$;

create or replace function private.finance_report(p_period text default 'month'::text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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
  v_other_expenses bigint := 0;
  v_inventory_purchases bigint := 0;
  v_book_profit bigint := 0;
  v_net_profit bigint := 0;
  v_total_revenue bigint := 0;
  v_margin numeric := 0;
  v_sources jsonb := '{}'::jsonb;
  v_estimated_days bigint := 0;
begin
  if v_period not in ('today','week','month','all') then
    v_period := 'month';
  end if;

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

  select coalesce(sum(o.delivery_fee),0), count(*)
    into v_delivery_revenue, v_orders
  from public.orders o
  where o.status = 'shipping'
    and exists (
      select 1
      from public.sales_log s
      where s.order_id = o.id
        and (v_start_ts is null or s.sold_at >= v_start_ts)
    );

  with shipped_by_day as (
    select (min(s.sold_at) at time zone 'Asia/Seoul')::date as day, o.id
    from public.orders o
    join public.sales_log s on s.order_id = o.id
    where o.status = 'shipping'
      and (v_start_ts is null or s.sold_at >= v_start_ts)
    group by o.id
  ), orders_per_day as (
    select day, count(*)::bigint as order_count
    from shipped_by_day
    group by day
  ), manual_postage as (
    select e.expense_date as day, sum(e.amount)::bigint as amount
    from public.finance_expenses e
    where e.category = 'postage'
      and (v_start_date is null or e.expense_date >= v_start_date)
    group by e.expense_date
  ), all_days as (
    select day from orders_per_day
    union
    select day from manual_postage
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

  v_book_profit := v_books_revenue - v_cost_of_goods;
  v_total_revenue := v_books_revenue + v_delivery_revenue;
  v_net_profit := v_total_revenue - v_cost_of_goods - v_postage - v_other_expenses;

  if v_total_revenue > 0 then
    v_margin := round((v_net_profit::numeric / v_total_revenue::numeric) * 100, 1);
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
    'postage_is_estimated', (v_estimated_days > 0),
    'postage_estimated_days', v_estimated_days,
    'other_expenses', v_other_expenses,
    'inventory_purchases', v_inventory_purchases,
    'cash_outflow_total', v_postage + v_other_expenses + v_inventory_purchases,
    'total_expenses', v_postage + v_other_expenses,
    'net_profit', v_net_profit,
    'margin_percent', v_margin,
    'sold_books', v_sold_books,
    'shipped_orders', v_orders,
    'source_book_revenue', v_sources
  );
end;
$function$;
