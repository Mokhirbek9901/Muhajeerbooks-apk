-- Customer-only public diagnostics use the existing trusted event credential.
-- These RPCs do not create orders, inbox messages or administrator sessions.
create or replace function public.event_customer_apns_test_recipients(p_event_secret text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.push_event_config where id=true
  and event_secret=p_event_secret and length(p_event_secret)>=20) then
  raise exception 'Unauthorized push event';
 end if;
 return query select a.token from private.customer_apns_devices a
 left join private.customer_device_apns link on link.token=a.token
 left join private.customer_device_profiles d on d.id=link.device_id
 where a.opted_in and a.last_seen_at>now()-interval '90 days'
  and length(a.token) between 64 and 200 and a.token ~ '^[0-9a-f]+$'
  and (link.device_id is null or (d.id is not null and d.revoked_at is null
   and d.install_id=a.install_id and d.phone_key=public._customer_phone_key(a.phone_digits)))
 order by a.last_seen_at desc limit 10000;
end $$;

create or replace function public.event_customer_fcm_test_recipients(p_event_secret text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.push_event_config where id=true
  and event_secret=p_event_secret and length(p_event_secret)>=20) then
  raise exception 'Unauthorized push event';
 end if;
 return query select f.token from private.native_fcm_devices f
 left join private.customer_device_profiles d on d.id=f.device_profile_id
 left join private.customer_pin_sessions s on f.device_profile_id is null and s.token_hash=f.session_hash
 where f.customer_opted_in and f.last_seen_at>now()-interval '90 days'
  and length(f.token) between 40 and 4096 and f.token ~ '^[A-Za-z0-9:_-]+$'
  and ((d.id is not null and d.revoked_at is null and d.install_id=f.install_id
    and d.phone_key=public._customer_phone_key(f.phone_digits))
   or (f.device_profile_id is null and s.expires_at>now() and s.install_id=f.install_id
    and s.phone_key=public._customer_phone_key(f.phone_digits)))
 order by f.last_seen_at desc limit 10000;
end $$;

revoke all on function public.event_customer_apns_test_recipients(text),
 public.event_customer_fcm_test_recipients(text) from public,anon,authenticated;
grant execute on function public.event_customer_apns_test_recipients(text),
 public.event_customer_fcm_test_recipients(text) to service_role;
