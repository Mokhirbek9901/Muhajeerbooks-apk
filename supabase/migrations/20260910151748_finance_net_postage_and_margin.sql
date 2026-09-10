create or replace function private.finance_report(p_period text default 'month')
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

  select coalesce(sum(o.delivery_fee),0), count(*)
    into v_delivery_revenue, v_orders
  from public.orders o
  where o.status = 'shipping'
    and exists (
      select 1 from public.sales_log s
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

  v_postage_covered := least(v_postage, v_delivery_revenue);
  v_store_postage := greatest(v_postage - v_postage_covered, 0);

  v_book_profit := v_books_revenue - v_cost_of_goods;
  v_operating_profit := v_book_profit - v_store_postage - v_other_expenses;
  v_cash_result := v_books_revenue - v_inventory_purchases - v_store_postage - v_other_expenses;
  v_total_revenue := v_books_revenue + v_delivery_revenue;

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
