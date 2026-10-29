-- PostgreSQL repetition bounds stop at 255; check length separately.
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
 if length(coalesce(p_token,'')) not between 40 and 4096
  or p_token !~ '^[A-Za-z0-9:_-]+$' then
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

