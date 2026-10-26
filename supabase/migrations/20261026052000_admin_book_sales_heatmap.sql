-- Admin-only 30-day sales activity; frozen unit prices and costs are
-- consulted for context, never recalculated from current book catalog.
-- This is independent of the date filter on the overall profit report.
create or replace function public.admin_book_sales_activity(p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_result jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;

  with calendar as (
    select day::date as sale_day
    from generate_series(v_today-29,v_today,interval '1 day') day
  ), recognized_sales as (
    select
      (coalesce(ps.first_sold_at,s.sold_at)
        at time zone 'Asia/Seoul')::date sale_day,
      s.id,
      coalesce(ps.unit_price,s.unit_price) unit_price,
      coalesce(ps.unit_cost,s.unit_cost) unit_cost,
      coalesce(ps.cost_known,s.unit_cost>0) cost_known
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id
     and ps.item_index=s.item_index
     and ps.unit_index=s.unit_index
    where coalesce(ps.first_sold_at,s.sold_at) >=
      ((v_today-29)::timestamp at time zone 'Asia/Seoul')
      and coalesce(ps.first_sold_at,s.sold_at) <
      ((v_today+1)::timestamp at time zone 'Asia/Seoul')
  ), totals as (
    select sale_day,
      count(*)::integer sold,
      coalesce(sum(unit_price),0)::bigint revenue,
      coalesce(sum(unit_price-unit_cost) filter(where cost_known),0)::bigint profit
    from recognized_sales
    group by sale_day
  )
  select jsonb_build_object(
    'from',v_today-29,'to',v_today,
    'days',coalesce(jsonb_agg(jsonb_build_object(
      'date',c.sale_day,
      'sold',coalesce(t.sold,0),
      'revenue',coalesce(t.revenue,0),
      'profit',coalesce(t.profit,0)
    ) order by c.sale_day),'[]'::jsonb),
    'total_sold',coalesce(sum(t.sold),0),
    'active_days',count(*) filter(where coalesce(t.sold,0)>0),
    'generated_at',now()
  ) into v_result
  from calendar c left join totals t using(sale_day);

  return v_result;
end;
$$;
revoke all on function public.admin_book_sales_activity(text)
  from public,anon,authenticated;
grant execute on function public.admin_book_sales_activity(text)
  to anon,authenticated,service_role;
comment on function public.admin_book_sales_activity(text) is
 '30-day Korea-local calendar of recognized sold book units, protected by admin_verify. Independent of report period filters.';
