drop policy if exists app_remote_config_public_read on public.app_remote_config;

create policy app_remote_config_public_read
on public.app_remote_config
for select
to anon, authenticated
using (true);

grant select on table public.app_remote_config to anon, authenticated;

create or replace function public.customer_app_config()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from public.app_remote_config;
$$;

revoke all on function public.customer_app_config() from public;
grant execute on function public.customer_app_config() to anon, authenticated;
