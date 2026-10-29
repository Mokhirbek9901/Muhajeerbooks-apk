-- FCM customer subscriptions must belong to an active verified customer session.
alter table private.native_fcm_devices add column if not exists session_hash text;

create or replace function public.customer_release_fcm(
  p_session text,p_token text,p_install_id text,p_enabled boolean default true
) returns boolean language plpgsql security definer set search_path='' as $$
declare
  k text:=private.pin_session_phone(p_session);
  h text:=encode(extensions.digest(p_session,'sha256'),'hex');
  phone text;
begin
  if k is null or not exists(select 1 from private.customer_pin_sessions s
      where s.token_hash=h and s.install_id=p_install_id and s.expires_at>now()) then
    raise exception 'Hisobingizga qayta kiring';
  end if;
  if not p_enabled then
    update private.native_fcm_devices set customer_opted_in=false,session_hash=null,phone_digits=''
      where install_id=p_install_id and session_hash=h;
    return true;
  end if;
  select display_phone into phone from private.customer_pin_profiles where phone_key=k;
  update private.native_fcm_devices set customer_opted_in=false,session_hash=null,phone_digits=''
    where install_id=p_install_id and token<>p_token;
  perform public.customer_register_native_fcm(p_token,phone,p_install_id);
  update private.native_fcm_devices set session_hash=h where token=p_token;
  return true;
end $$;
revoke all on function public.customer_release_fcm(text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.customer_release_fcm(text,text,text,boolean) to service_role;

create or replace function public.event_native_fcm_for_phone(p_event_secret text,p_phone text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from private.push_event_config where id=true
      and event_secret=p_event_secret and length(p_event_secret)>=20) then
    raise exception 'Unauthorized push event';
  end if;
  return query select d.token from private.native_fcm_devices d
    join private.customer_pin_sessions s on s.token_hash=d.session_hash
    where d.customer_opted_in and s.expires_at>now()
      and s.install_id=d.install_id
      and s.phone_key=public._customer_phone_key(p_phone)
      and public._customer_phone_key(d.phone_digits)=s.phone_key
      and d.last_seen_at>now()-interval '90 days'
    order by d.last_seen_at desc limit 20;
end $$;

create or replace function public.event_admin_native_fcm(p_event_secret text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from private.push_event_config where id=true
      and event_secret=p_event_secret and length(p_event_secret)>=20) then
    raise exception 'Unauthorized push event';
  end if;
  return query select d.token from private.native_fcm_devices d
    where d.admin_verified_at>now()-interval '30 days'
      and d.last_seen_at>now()-interval '90 days'
    order by d.admin_verified_at desc limit 20;
end $$;

create or replace function public.admin_native_fcm_devices(p_secret text)
returns table(token text) language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Unauthorized'; end if;
  return query select d.token from private.native_fcm_devices d
    join private.customer_pin_sessions s on s.token_hash=d.session_hash
    where d.customer_opted_in and s.expires_at>now()
      and s.install_id=d.install_id and s.phone_key=public._customer_phone_key(d.phone_digits)
      and d.last_seen_at>now()-interval '90 days'
    order by d.last_seen_at desc limit 10000;
end $$;
revoke all on function public.event_native_fcm_for_phone(text,text),
    public.event_admin_native_fcm(text),public.admin_native_fcm_devices(text)
    from public,anon,authenticated;
grant execute on function public.event_native_fcm_for_phone(text,text),
    public.event_admin_native_fcm(text),public.admin_native_fcm_devices(text) to service_role;
