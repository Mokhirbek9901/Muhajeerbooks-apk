-- Android native FCM devices, isolated from browser WebPush registrations.
-- Private tokens are read only by verified server-side service-role functions.
create table if not exists private.native_fcm_devices (
  token text primary key,
  phone_digits text not null default '',
  install_id text not null default '',
  opted_in boolean not null default true,
  admin_verified_at timestamptz,
  last_seen_at timestamptz not null default now()
);
revoke all on private.native_fcm_devices from public, anon, authenticated;
create index if not exists idx_native_fcm_phone_last
  on private.native_fcm_devices(phone_digits, last_seen_at desc);

create or replace function public.customer_register_native_fcm(
  p_token text, p_phone text, p_install_id text
) returns boolean
language plpgsql security definer set search_path = ''
as $fn$
declare digits text := regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
begin
  if length(coalesce(p_token,'')) < 40 or length(p_token) > 4096 or
     p_token !~ '^[A-Za-z0-9:_-]+$' or
     length(coalesce(p_install_id,'')) < 12 or length(p_install_id) > 120 or
     length(digits) < 8 or length(digits) > 30 then
    raise exception 'Invalid mobile push registration';
  end if;
  insert into private.native_fcm_devices(token,phone_digits,install_id,opted_in,last_seen_at)
  values (trim(p_token),digits,trim(p_install_id),true,now())
  on conflict(token) do update
    set phone_digits=excluded.phone_digits,
        install_id=excluded.install_id,
        opted_in=true,
        last_seen_at=now();
  return true;
end;
$fn$;

create or replace function public.customer_unregister_native_fcm(
  p_install_id text
) returns boolean
language plpgsql security definer set search_path = ''
as $fn$
begin
  if length(coalesce(p_install_id,'')) < 12 or length(p_install_id) > 120 then
    raise exception 'Invalid installation ID';
  end if;
  update private.native_fcm_devices set opted_in=false, phone_digits='',last_seen_at=now()
   where install_id=trim(p_install_id);
  return true;
end;
$fn$;

create or replace function public.admin_register_native_fcm(
  p_secret text, p_token text
) returns boolean
language plpgsql security definer set search_path = ''
as $fn$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
  if length(coalesce(p_token,'')) < 40 or length(p_token) > 4096 or
     p_token !~ '^[A-Za-z0-9:_-]+$' then raise exception 'Invalid FCM token'; end if;
  insert into private.native_fcm_devices(token,admin_verified_at,last_seen_at)
  values(trim(p_token),now(),now())
  on conflict(token) do update set admin_verified_at=now(),last_seen_at=now();
  return true;
end;
$fn$;

create or replace function public.event_native_fcm_for_phone(
  p_event_secret text, p_phone text
) returns table(token text)
language plpgsql security definer set search_path = ''
as $fn$
declare v_expected text;
begin
  select event_secret into v_expected from private.push_event_config where id = true;
  if v_expected is null or p_event_secret is distinct from v_expected
     then raise exception 'Unauthorized push event'; end if;
  return query select d.token from private.native_fcm_devices d
   where d.opted_in and d.phone_digits = regexp_replace(coalesce(p_phone,''),'[^0-9]','','g')
     and d.last_seen_at > now() - interval '90 days'
   order by d.last_seen_at desc limit 20;
end;
$fn$;

create or replace function public.event_admin_native_fcm(
  p_event_secret text
) returns table(token text)
language plpgsql security definer set search_path = ''
as $fn$
declare v_expected text;
begin
  select event_secret into v_expected from private.push_event_config where id = true;
  if v_expected is null or p_event_secret is distinct from v_expected
     then raise exception 'Unauthorized push event'; end if;
  return query select d.token from private.native_fcm_devices d
   where d.opted_in and d.admin_verified_at >= now() - interval '30 days'
   order by d.admin_verified_at desc limit 20;
end;
$fn$;

create or replace function public.admin_native_fcm_devices(
  p_secret text
) returns table(token text)
language plpgsql security definer set search_path = ''
as $fn$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
  return query select d.token from private.native_fcm_devices d
   where d.opted_in and d.last_seen_at > now() - interval '90 days'
   order by d.last_seen_at desc limit 10000;
end;
$fn$;

revoke all on function public.customer_register_native_fcm(text,text,text) from public,anon,authenticated;
revoke all on function public.customer_unregister_native_fcm(text) from public,anon,authenticated;
revoke all on function public.admin_register_native_fcm(text,text) from public,anon,authenticated;
revoke all on function public.event_native_fcm_for_phone(text,text) from public,anon,authenticated;
revoke all on function public.event_admin_native_fcm(text) from public,anon,authenticated;
revoke all on function public.admin_native_fcm_devices(text) from public,anon,authenticated;
grant execute on function public.customer_register_native_fcm(text,text,text) to service_role;
grant execute on function public.customer_unregister_native_fcm(text) to service_role;
grant execute on function public.admin_register_native_fcm(text,text) to service_role;
grant execute on function public.event_native_fcm_for_phone(text,text) to service_role;
grant execute on function public.event_admin_native_fcm(text) to service_role;
grant execute on function public.admin_native_fcm_devices(text) to service_role;
