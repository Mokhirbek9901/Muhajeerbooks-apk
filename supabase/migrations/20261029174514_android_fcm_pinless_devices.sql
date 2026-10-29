-- Durable Android subscriptions for PINless customers. A typed phone is never
-- an authorization credential; every order notification checks exact ownership.
alter table private.native_fcm_devices add column if not exists device_profile_id uuid
 references private.customer_device_profiles(id);
create index if not exists native_fcm_devices_profile on private.native_fcm_devices(device_profile_id);

create or replace function public.customer_release_fcm(
 p_session text,p_token text,p_install_id text,p_enabled boolean default true
) returns boolean language plpgsql security definer set search_path='' as $$
declare d private.customer_device_profiles; k text; h text; phone text;
begin
 if coalesce(p_install_id,'') !~ '^.{12,120}$' or p_enabled is null then
  raise exception 'Qurilma push ma’lumoti noto‘g‘ri'; end if;
 if coalesce(p_session,'') like 'device:%' then
  d:=private.customer_device(p_session);
  -- Serialize registration with profile revocation, including logout races.
  perform 1 from private.customer_device_profiles where id=d.id and revoked_at is null for share;
  if not found or d.install_id is distinct from p_install_id then
   raise exception 'Qurilma kirishi tasdiqlanmadi'; end if;
  phone:=d.display_phone;
 else
  k:=private.pin_session_phone(p_session);
  h:=encode(extensions.digest(p_session,'sha256'),'hex');
  perform 1 from private.customer_pin_sessions s where s.token_hash=h
   and s.install_id=p_install_id and s.expires_at>now() for share;
  if k is null or not found then raise exception 'Hisobingizga qayta kiring'; end if;
  select display_phone into phone from private.customer_pin_profiles where phone_key=k;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('fcm-install:'||p_install_id,29));
 if not p_enabled then
  update private.native_fcm_devices set customer_opted_in=false,session_hash=null,
   device_profile_id=null,phone_digits=''
   where install_id=p_install_id and
    ((d.id is not null and device_profile_id=d.id)
     or (d.id is null and device_profile_id is null and session_hash=h));
  return true;
 end if;
 if coalesce(p_token,'') !~ '^[A-Za-z0-9:_-]{40,4096}$' then
  raise exception 'Invalid mobile push registration'; end if;
 update private.native_fcm_devices set customer_opted_in=false,session_hash=null,
  device_profile_id=null,phone_digits=''
  where install_id=p_install_id and token<>p_token and
   ((d.id is not null and device_profile_id=d.id)
    or (d.id is null and device_profile_id is null and session_hash=h));
 insert into private.native_fcm_devices(token,phone_digits,install_id,customer_opted_in,
  last_seen_at,session_hash,device_profile_id)
 values(p_token,regexp_replace(phone,'[^0-9]','','g'),p_install_id,true,now(),h,d.id)
 on conflict(token) do update set phone_digits=excluded.phone_digits,
  install_id=excluded.install_id,customer_opted_in=true,last_seen_at=now(),
  session_hash=excluded.session_hash,device_profile_id=excluded.device_profile_id;
 return true;
end $$;

create or replace function public.event_native_fcm_for_order(
 p_event_secret text,p_phone text,p_order_id uuid
) returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.push_event_config where id=true
  and event_secret=p_event_secret and length(p_event_secret)>=20) then
  raise exception 'Unauthorized push event'; end if;
 return query select f.token from private.native_fcm_devices f
 left join private.customer_device_profiles d on d.id=f.device_profile_id
 left join private.customer_pin_sessions s on f.device_profile_id is null and s.token_hash=f.session_hash
 where f.customer_opted_in and f.last_seen_at>now()-interval '90 days'
  and public._customer_phone_key(f.phone_digits)=public._customer_phone_key(p_phone)
  and exists(select 1 from public.orders o where o.id=p_order_id
   and public._customer_phone_key(o.phone)=public._customer_phone_key(p_phone))
  and ((d.id is not null and d.revoked_at is null and d.install_id=f.install_id
    and d.phone_key=public._customer_phone_key(p_phone)
    and private.customer_device_owns_order(d,p_order_id))
   or (f.device_profile_id is null and s.expires_at>now() and s.install_id=f.install_id
    and s.phone_key=public._customer_phone_key(p_phone)
    and exists(select 1 from private.release_order_owners o where o.order_id=p_order_id and o.phone_key=s.phone_key)))
 order by f.last_seen_at desc limit 20;
end $$;

-- Old servers have no order ID. Never return PINless devices to that lookup.
create or replace function public.event_native_fcm_for_phone(p_event_secret text,p_phone text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.push_event_config where id=true
  and event_secret=p_event_secret and length(p_event_secret)>=20) then raise exception 'Unauthorized push event'; end if;
 return query select f.token from private.native_fcm_devices f
 join private.customer_pin_sessions s on s.token_hash=f.session_hash
 where f.device_profile_id is null and f.customer_opted_in and s.expires_at>now()
  and s.install_id=f.install_id and s.phone_key=public._customer_phone_key(p_phone)
  and public._customer_phone_key(f.phone_digits)=s.phone_key
  and f.last_seen_at>now()-interval '90 days' order by f.last_seen_at desc limit 20;
end $$;

create or replace function public.admin_native_fcm_devices(p_secret text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Unauthorized'; end if;
 return query select f.token from private.native_fcm_devices f
 left join private.customer_device_profiles d on d.id=f.device_profile_id
 left join private.customer_pin_sessions s on f.device_profile_id is null and s.token_hash=f.session_hash
 where f.customer_opted_in and f.last_seen_at>now()-interval '90 days'
  and ((d.id is not null and d.revoked_at is null and d.install_id=f.install_id
    and d.phone_key=public._customer_phone_key(f.phone_digits))
   or (f.device_profile_id is null and s.expires_at>now() and s.install_id=f.install_id
    and s.phone_key=public._customer_phone_key(f.phone_digits)))
 order by f.last_seen_at desc limit 10000;
end $$;

create or replace function private.revoke_customer_device_fcm()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.revoked_at is not null then
  update private.native_fcm_devices set customer_opted_in=false,session_hash=null,
   device_profile_id=null,phone_digits='' where device_profile_id=new.id;
 end if;
 return new;
end $$;
create trigger customer_device_fcm_revoked after update of revoked_at
 on private.customer_device_profiles for each row execute function private.revoke_customer_device_fcm();

revoke all on function public.customer_release_fcm(text,text,text,boolean),
 public.event_native_fcm_for_order(text,text,uuid),public.event_native_fcm_for_phone(text,text),
 public.admin_native_fcm_devices(text),private.revoke_customer_device_fcm() from public,anon,authenticated;
grant execute on function public.customer_release_fcm(text,text,text,boolean),
 public.event_native_fcm_for_order(text,text,uuid),public.event_native_fcm_for_phone(text,text),
 public.admin_native_fcm_devices(text) to service_role;
