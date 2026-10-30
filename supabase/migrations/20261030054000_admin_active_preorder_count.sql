-- Only non-cancelled web and native preorder rows count toward the admin
-- home dashboard. Keep this server-authoritative for all clients.
create or replace function public.admin_active_preorder_count(p_secret text)
returns bigint language plpgsql security definer set search_path='' as $$
declare total bigint;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Ruxsat yo‘q';
  end if;
  select (select count(*) from public.preorders where status <> 'cancelled')
       + (select count(*) from public.web_preorder_requests where status <> 'cancelled')
    into total;
  return total;
end $$;
revoke all on function public.admin_active_preorder_count(text) from public,anon,authenticated;
grant execute on function public.admin_active_preorder_count(text) to service_role;
