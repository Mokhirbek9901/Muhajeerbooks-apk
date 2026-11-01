-- Read-only summary for dashboard. Does not modify any preorder, payment,
-- status, reserved stock, or customer record.
create or replace function public.admin_active_preorder_summary(p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare result jsonb;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Ruxsat yo‘q';
  end if;

  with active as (
    select 'native:' || p.id::text as reference,
      regexp_replace(coalesce(p.phone,''), '[^0-9]', '', 'g') as phone,
      greatest(coalesce(p.quantity,0),0) as units
    from public.preorders p
    where p.status <> 'cancelled'
      and not exists (
        select 1 from private.admin_preorder_hidden h
        where h.source='native' and h.order_id=p.id::text
      )
    union all
    select 'web:' || w.id::text,
      regexp_replace(coalesce(w.phone,''), '[^0-9]', '', 'g'),
      greatest(coalesce(w.quantity,0),0)
    from public.web_preorder_requests w
    where w.status <> 'cancelled'
      and not exists (
        select 1 from private.admin_preorder_hidden h
        where h.source='web' and h.order_id=w.id::text
      )
  )
  select jsonb_build_object(
    'people', count(distinct case when length(phone) >= 8 then phone else reference end),
    'books', coalesce(sum(units),0),
    'requests', count(*)
  ) into result from active;
  return result;
end $fn$;
revoke all on function public.admin_active_preorder_summary(text)
  from public, anon, authenticated;
grant execute on function public.admin_active_preorder_summary(text) to service_role;