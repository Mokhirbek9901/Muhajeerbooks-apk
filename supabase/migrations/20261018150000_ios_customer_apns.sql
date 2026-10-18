-- Native iPhone APNs customer tokens, separate from verified admin APNs tokens.
-- Tokens are never exposed through customer-facing APIs.
create table if not exists private.customer_apns_devices (
  token text primary key,
  phone_digits text not null default '',
  install_id text not null default '',
  opted_in boolean not null default true,
  last_seen_at timestamptz not null default now()
);
revoke all on private.customer_apns_devices from public,anon,authenticated;
create index if not exists idx_customer_apns_phone
  on private.customer_apns_devices(phone_digits, last_seen_at desc);

create or replace function public.customer_register_native_apns(
  p_token text, p_phone text, p_install_id text
) returns boolean
language plpgsql security definer set search_path = ''
as $fn$
declare digits text := regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
begin
  if p_token is null or p_token !~ '^[0-9a-fA-F]{64,200}$'
    or length(digits)<8 or length(digits)>30
    or length(coalesce(p_install_id,''))<12 or length(p_install_id)>120
  then raise exception 'Invalid iOS push registration'; end if;
  insert into private.customer_apns_devices(token,phone_digits,install_id,opted_in,last_seen_at)
  values (lower(p_token),digits,trim(p_install_id),true,now())
  on conflict (token) do update set
    phone_digits=excluded.phone_digits,
    install_id=excluded.install_id,
    opted_in=true,
    last_seen_at=now();
  return true;
end;
$fn$;

create or replace function public.customer_unregister_native_apns(
  p_install_id text
) returns boolean language plpgsql security definer set search_path = ''
as $fn$
begin
  if length(coalesce(p_install_id,''))<12 or length(p_install_id)>120
    then raise exception 'Invalid install ID'; end if;
  update private.customer_apns_devices
    set opted_in=false,phone_digits='',last_seen_at=now()
    where install_id=trim(p_install_id);
  return true;
end;
$fn$;

create or replace function public.event_customer_apns_for_phone(
  p_event_secret text, p_phone text
) returns table(token text)
language plpgsql security definer set search_path = ''
as $fn$
declare expected text;
begin
  select c.event_secret into expected from private.push_event_config c where c.id=true;
  if expected is null or p_event_secret is distinct from expected
    then raise exception 'Unauthorized push event'; end if;
  return query select d.token from private.customer_apns_devices d
    where d.opted_in and d.phone_digits=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g')
      and d.last_seen_at>now()-interval '90 days'
    order by d.last_seen_at desc limit 20;
end;
$fn$;

create or replace function public.admin_customer_apns_devices(
  p_secret text
) returns table(token text)
language plpgsql security definer set search_path = ''
as $fn$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
  return query select d.token from private.customer_apns_devices d
    where d.opted_in and d.last_seen_at>now()-interval '90 days'
    order by d.last_seen_at desc limit 10000;
end;
$fn$;

revoke all on function public.customer_register_native_apns(text,text,text) from public,anon,authenticated;
revoke all on function public.customer_unregister_native_apns(text) from public,anon,authenticated;
revoke all on function public.event_customer_apns_for_phone(text,text) from public,anon,authenticated;
revoke all on function public.admin_customer_apns_devices(text) from public,anon,authenticated;
grant execute on function public.customer_register_native_apns(text,text,text) to service_role;
grant execute on function public.customer_unregister_native_apns(text) to service_role;
grant execute on function public.event_customer_apns_for_phone(text,text) to service_role;
grant execute on function public.admin_customer_apns_devices(text) to service_role;
