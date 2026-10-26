-- Read-only admin overview of recorded purchase batches.
-- Legacy sales do not identify a purchased lot: therefore this report
-- explicitly labels its projected margin as hypothetical, NOT realized profit.
create or replace function public.admin_book_profit_batches(p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_report jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;

  with rows as (
    select bt.id,
      bt.book_id,
      b.title as book_title,
      bt.quantity,
      bt.unit_cost,
      bt.purchased_at,
      bt.batch_group_id,
      coalesce(g.title, to_char(bt.purchased_at,'DD.MM.YYYY')||' partiyasi') as group_title,
      coalesce(bt.batch_group_id::text,'date:'||bt.purchased_at::text) as group_key,
      coalesce(g.batch_date,bt.purchased_at) as group_date,
      (case when b.discount_percent>0
        and (b.discount_ends_at is null or b.discount_ends_at>now())
        then round(b.price*(100-b.discount_percent)/100.0)::integer
        else b.price end) as sale_price
    from public.web_book_batches bt
    join public.books b on b.id=bt.book_id
    left join public.web_batch_groups g on g.id=bt.batch_group_id
  ), calculations as (
    select r.*,
      case when unit_cost>0 and sale_price>0
        then ((sale_price::bigint-unit_cost::bigint)*quantity::bigint)
        else null end as projected_profit
    from rows r
  ), grouped as (
    select group_key,max(group_title) as title,
      max(group_date) as group_date,
      count(*)::integer as book_rows,
      count(distinct book_id)::integer as book_titles,
      sum(quantity)::bigint as purchased_units,
      sum(unit_cost::bigint*quantity)::bigint as total_purchase_cost,
      coalesce(sum(projected_profit),0)::bigint as projected_profit,
      count(*) filter(where projected_profit is null)::integer as unpriced_rows
    from calculations group by group_key
  )
  select jsonb_build_object(
    'groups',coalesce((
      select jsonb_agg(jsonb_build_object(
        'group_key',group_key,'title',title,'date',group_date,
        'book_rows',book_rows,'book_titles',book_titles,
        'purchased_units',purchased_units,
        'total_purchase_cost',total_purchase_cost,
        'projected_profit',projected_profit,
        'unpriced_rows',unpriced_rows
      ) order by group_date desc,title)
      from grouped
    ),'[]'::jsonb),
    'lots',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'group_key',group_key,
        'book_id',book_id,'book_title',book_title,
        'quantity',quantity,'unit_cost',unit_cost,
        'sale_price',sale_price,'purchased_at',purchased_at,
        'projected_profit',projected_profit
      ) order by purchased_at desc,id desc)
      from calculations
    ),'[]'::jsonb),
    'allocation_note',
      'Sotuv tarixi xarid partiyasiga biriktirilmagan. Partiya foydasi — barcha kirgan nusxalar hozirgi sotuv narxida sotilsa kutiladigan taxminiy yalpi foyda.',
    'generated_at',now()
  ) into v_report;
  return v_report;
end;
$$;

revoke all on function public.admin_book_profit_batches(text) from public,anon,authenticated;
grant execute on function public.admin_book_profit_batches(text) to anon,authenticated,service_role;
comment on function public.admin_book_profit_batches(text) is
 'Admin-only purchase batches with hypothetical gross profit; no claim that historical sales belong to a specific lot.';
