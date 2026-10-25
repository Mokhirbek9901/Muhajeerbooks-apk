-- Custom date-range selection for the real admin dashboard.
-- Uses the original saved sale timestamp, cost and price without rewriting
-- historical sales. The previous two-argument RPC remains available to
-- older app builds.
create or replace function public.admin_book_profit_report(
  p_secret text, p_period text default 'all',
  p_from text default null, p_to text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_start date;
  v_end date;
  v_result jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_period not in ('all','today','yesterday','week','month','previous_month','custom') then
    raise exception 'Davr filtri noto‘g‘ri';
  end if;
  if p_period='custom' then
    if p_from is null or p_to is null or
       p_from !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or
       p_to !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Sanalarni kiriting';
    end if;
    v_start:=p_from::date;
    v_end:=p_to::date + 1;
    if v_start>=v_end then
      raise exception 'Noto‘g‘ri sana oralig‘i';
    end if;
  elsif p_period='today' then
    v_start:=v_today; v_end:=v_today+1;
  elsif p_period='yesterday' then
    v_start:=v_today-1; v_end:=v_today;
  elsif p_period='week' then
    v_start:=v_today-6; v_end:=v_today+1;
  elsif p_period='month' then
    v_start:=date_trunc('month',v_today::timestamp)::date;
    v_end:=(v_start+interval '1 month')::date;
  elsif p_period='previous_month' then
    v_end:=date_trunc('month',v_today::timestamp)::date;
    v_start:=(v_end-interval '1 month')::date;
  end if;

  with sale_rows as (
    select s.id,s.order_id,s.item_index,s.unit_index,s.book_id,s.title,s.source,
      coalesce(ps.first_sold_at,s.sold_at) as sold_at,
      coalesce(ps.unit_price,s.unit_price) as unit_price,
      coalesce(ps.unit_cost,s.unit_cost) as unit_cost,
      coalesce(ps.cost_known,s.unit_cost>0) known
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id
      and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (v_start is null or (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date>=v_start)
      and (v_end is null or (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date<v_end)
  ), by_book as (
    select book_id,
      count(*)::integer quantity,
      sum(unit_price)::bigint revenue,
      coalesce(sum(unit_price-unit_cost) filter(where known),0)::bigint profit,
      count(*) filter(where not known)::integer unknown_count
    from sale_rows group by book_id
  )
  select jsonb_build_object(
    'period',p_period,'generated_at',now(),
    'summary',(select jsonb_build_object(
      'sold',count(*),'revenue',coalesce(sum(unit_price),0),
      'profit',coalesce(sum(unit_price-unit_cost) filter(where known),0),
      'unknown_cost_sales',count(*) filter(where not known)
    ) from sale_rows),
    'books',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',b.id,'title',b.title,'author',b.author,'category',b.category,
        'stock',b.stock,'cost_price',b.cost_price,
        'sale_price',case
          when b.discount_percent>0
            and (b.discount_ends_at is null or b.discount_ends_at>now())
          then round(b.price*(100-b.discount_percent)/100.0)::integer
          else b.price end,
        'image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url),
        'is_active',b.is_active,
        'sold',coalesce(a.quantity,0),'revenue',coalesce(a.revenue,0),
        'profit',coalesce(a.profit,0),'unknown_cost_sales',coalesce(a.unknown_count,0)
      ) order by b.title)
      from public.books b left join by_book a on a.book_id=b.id
    ),'[]'::jsonb),
    'unlinked',(select jsonb_build_object(
      'sold',coalesce(quantity,0),'revenue',coalesce(revenue,0),
      'profit',coalesce(profit,0),'unknown_cost_sales',coalesce(unknown_count,0)
    ) from by_book where book_id is null),
    'daily',coalesce((
      select jsonb_agg(jsonb_build_object(
        'date',date_key,'sold',qty,'revenue',revenue,'profit',profit)
        order by date_key)
      from (
        select (sold_at at time zone 'Asia/Seoul')::date date_key,
          count(*) qty,sum(unit_price)::bigint revenue,
          coalesce(sum(unit_price-unit_cost) filter(where known),0)::bigint profit
        from sale_rows group by 1 order by 1
      ) d
    ),'[]'::jsonb),
    'recent_sales',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'book_id',s.book_id,'title',s.title,
        'unit_price',s.unit_price,'unit_cost',s.unit_cost,
        'cost_known',s.known,'sold_at',s.sold_at,
        'source',s.source
      ) order by s.sold_at desc,s.id desc)
      from (select * from sale_rows order by sold_at desc,id desc limit 250) s
    ),'[]'::jsonb),
    'legacy_sales_count',(select count(*) from public.legacy_sales_history)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on private.book_sale_profit_snapshots from public,anon,authenticated;
revoke execute on function public.admin_book_profit_report(text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.admin_book_profit_report(text,text,text,text)
  to anon,authenticated,service_role;

comment on function public.admin_book_profit_report(text,text,text,text) is
 'Admin-only report: each realized sale retains original unit_price/unit_cost. Costless sales are explicitly excluded from verified profit.';
