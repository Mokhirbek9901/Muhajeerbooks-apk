-- Verified admin browser devices receive new orders from both web and iOS/Android.
-- Customer web push subscribers never become admin subscribers implicitly.
alter table public.push_subscriptions
  add column if not exists admin_verified_at timestamptz;

create or replace function public.admin_register_order_push_device(
  p_secret text, p_endpoint text
) returns boolean
language plpgsql security definer set search_path = public, pg_temp
as $fn$
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Unauthorized admin';
  end if;
  if length(trim(coalesce(p_endpoint,''))) < 20 or length(p_endpoint) > 2048 then
    raise exception 'Invalid push endpoint';
  end if;
  update public.push_subscriptions
     set admin_verified_at = now(), updated_at = now()
   where endpoint = trim(p_endpoint);
  if not found then
    raise exception 'Enable push notifications on this browser first';
  end if;
  return true;
end;
$fn$;

create or replace function public.event_admin_order_push_subscriptions(
  p_event_secret text
) returns table(endpoint text, p256dh text, auth text)
language plpgsql security definer set search_path = public, private, pg_temp
as $fn$
declare expected text;
begin
  select c.event_secret into expected from private.push_event_config c where c.id = true;
  if expected is null or p_event_secret is distinct from expected then
    raise exception 'Unauthorized push event';
  end if;
  return query
    select s.endpoint, s.p256dh, s.auth
      from public.push_subscriptions s
     where s.admin_verified_at >= now() - interval '30 days'
     order by s.admin_verified_at desc limit 20;
end;
$fn$;

revoke all on function public.admin_register_order_push_device(text,text)
  from public, anon, authenticated;
revoke all on function public.event_admin_order_push_subscriptions(text)
  from public, anon, authenticated;
grant execute on function public.admin_register_order_push_device(text,text)
  to service_role;
grant execute on function public.event_admin_order_push_subscriptions(text)
  to service_role;
