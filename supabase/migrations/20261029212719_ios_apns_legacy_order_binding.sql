-- A legacy phone-only APNs registration may receive public announcements,
-- but private order notifications require proof of the authenticated session.
alter table private.customer_apns_devices add column if not exists session_hash text;
create index if not exists customer_apns_devices_session on private.customer_apns_devices(session_hash)
 where session_hash is not null;

create or replace function public.customer_release_apns(
 p_session text,p_token text,p_install_id text,p_enabled boolean default true
) returns boolean language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session);
 h text:=encode(extensions.digest(coalesce(p_session,''),'sha256'),'hex');
begin
 if k is null or not exists(select 1 from private.customer_pin_sessions s
  where s.token_hash=h and s.install_id=p_install_id and s.phone_key=k and s.expires_at>now()) then
  raise exception 'Hisobingizga qayta kiring';
 end if;
 if not p_enabled then
  update private.customer_apns_devices set opted_in=false,session_hash=null
   where session_hash=h and install_id=p_install_id;
  return true;
 end if;
 if p_token is null or p_token !~ '^[0-9a-fA-F]{64,200}$' then raise exception 'Invalid iOS push registration'; end if;
 perform pg_advisory_xact_lock(hashtextextended('apns-install:'||p_install_id,29));
 update private.customer_apns_devices set opted_in=false,session_hash=null
  where session_hash=h and install_id=p_install_id and token<>lower(p_token);
 perform public.customer_register_native_apns(p_token,
  (select display_phone from private.customer_pin_profiles where phone_key=k),p_install_id);
 update private.customer_apns_devices set session_hash=h where token=lower(p_token);
 delete from private.customer_device_apns where token=lower(p_token);
 return true;
end $$;

create or replace function public.event_customer_device_apns(p_event_secret text,p_phone text,p_order_id uuid)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.push_event_config where id=true
  and event_secret=p_event_secret and length(p_event_secret)>=20) then raise exception 'Unauthorized push event'; end if;
 return query select a.token from private.customer_apns_devices a
 left join private.customer_device_apns link on link.token=a.token
 left join private.customer_device_profiles d on d.id=link.device_id
 left join private.customer_pin_sessions s on link.device_id is null and s.token_hash=a.session_hash
 where a.opted_in and a.last_seen_at>now()-interval '90 days'
  and public._customer_phone_key(a.phone_digits)=public._customer_phone_key(p_phone)
  and exists(select 1 from public.orders o where o.id=p_order_id
   and public._customer_phone_key(o.phone)=public._customer_phone_key(p_phone))
  and ((d.id is not null and d.revoked_at is null and d.install_id=a.install_id
    and d.phone_key=public._customer_phone_key(p_phone) and private.customer_device_owns_order(d,p_order_id))
   or (link.device_id is null and s.expires_at>now() and s.install_id=a.install_id
    and s.phone_key=public._customer_phone_key(p_phone)
    and exists(select 1 from private.release_order_owners own where own.order_id=p_order_id and own.phone_key=s.phone_key)))
 order by a.last_seen_at desc limit 20;
end $$;
revoke all on function public.customer_release_apns(text,text,text,boolean),
 public.event_customer_device_apns(text,text,uuid) from public,anon,authenticated;
grant execute on function public.customer_release_apns(text,text,text,boolean),
 public.event_customer_device_apns(text,text,uuid) to service_role;
