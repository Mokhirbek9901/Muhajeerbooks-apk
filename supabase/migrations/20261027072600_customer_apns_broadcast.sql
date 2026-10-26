-- MB push: admin-authorized broadcast tokens only; customer orders stay private.
create or replace function public.admin_release_apns_broadcast_recipients(p_secret text)
returns table(token text)
language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public._admin_secret_ok(p_secret),false) then
    raise exception 'Admin ruxsati tasdiqlanmadi';
  end if;
  return query
    select distinct d.token
    from private.customer_apns_devices d
    where d.opted_in
      and d.last_seen_at > now() - interval '90 days'
      and d.token ~ '^[0-9a-f]{64,200}$'
    order by d.token
    limit 10000;
end $$;
revoke all on function public.admin_release_apns_broadcast_recipients(text)
  from public, anon, authenticated;
grant execute on function public.admin_release_apns_broadcast_recipients(text) to service_role;
