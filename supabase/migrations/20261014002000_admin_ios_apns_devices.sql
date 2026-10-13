-- Native iOS TestFlight administrator APNs devices.
-- Tokens are never readable from client Supabase Data API.
create table if not exists private.admin_apns_devices (
 token text primary key,
 registered_at timestamptz not null default now(),
 last_seen_at timestamptz not null default now(),
 active boolean not null default true
);
revoke all on private.admin_apns_devices from public, anon, authenticated;

create or replace function public.admin_register_apns_device(p_secret text, p_token text)
returns boolean language plpgsql security definer set search_path = ''
as $fn$
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
 if p_token is null or p_token !~ '^[0-9a-fA-F]{64,200}$' then
    raise exception 'Invalid APNs device token';
 end if;
 insert into private.admin_apns_devices(token, active, last_seen_at)
 values (lower(p_token),true,now())
 on conflict (token) do update set active=true,last_seen_at=now();
 return true;
end;
$fn$;
revoke all on function public.admin_register_apns_device(text,text) from public,anon,authenticated;
grant execute on function public.admin_register_apns_device(text,text) to service_role;

create or replace function public.event_admin_apns_devices(p_event_secret text)
returns table(token text) language plpgsql security definer set search_path = ''
as $fn$
begin
 if not exists (select 1 from private.push_event_config
                where id=true and event_secret=p_event_secret
                  and length(p_event_secret)>=20)
 then raise exception 'Unauthorized'; end if;
 return query select d.token from private.admin_apns_devices d
 where d.active=true and d.last_seen_at>now()-interval '90 days'
 order by d.last_seen_at desc limit 30;
end;
$fn$;
revoke all on function public.event_admin_apns_devices(text) from public,anon,authenticated;
grant execute on function public.event_admin_apns_devices(text) to service_role;
