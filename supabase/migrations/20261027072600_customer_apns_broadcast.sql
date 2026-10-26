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

-- A private order is sent to the last admin-verified iPhone only.
-- Enrolling a new phone revokes prior native admin device grants.
create or replace function public.admin_register_apns_device(p_secret text,p_token text)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public._admin_secret_ok(p_secret),false) then
    raise exception 'Admin paroli noto‘g‘ri';
  end if;
  if p_token is null or p_token !~ '^[0-9a-fA-F]{64,200}$' then
    raise exception 'iPhone APNs tokeni yaroqsiz';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('muhajeer-single-admin-apns',29));
  update private.admin_apns_devices
    set active=false where token <> lower(p_token) and active;
  insert into private.admin_apns_devices(token,active,last_seen_at)
  values(lower(p_token),true,now())
  on conflict(token) do update set active=true,last_seen_at=now();
  return true;
end $$;

create or replace function public.event_admin_apns_devices(p_event_secret text)
returns table(token text)
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from private.push_event_config
      where id=true and event_secret=p_event_secret and length(p_event_secret)>=20) then
    raise exception 'Admin xabar huquqi yo‘q';
  end if;
  return query select d.token from private.admin_apns_devices d
    where d.active and d.last_seen_at>now()-interval '90 days'
    order by d.last_seen_at desc limit 1;
end $$;
revoke all on function public.admin_register_apns_device(text,text),
    public.event_admin_apns_devices(text) from public,anon,authenticated;
grant execute on function public.admin_register_apns_device(text,text),
    public.event_admin_apns_devices(text) to service_role;
