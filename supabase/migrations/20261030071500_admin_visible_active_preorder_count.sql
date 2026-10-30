-- Count only visible, non-cancelled reservations in the admin dashboard.
-- Hidden historical reservations should not inflate the Home counter.
create or replace function public.admin_active_preorder_count(p_secret text)
returns bigint
language plpgsql security definer
set search_path = ''
as $$
declare total bigint;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Ruxsat yo‘q';
  end if;
  select (
    select count(*) from public.preorders p
    where p.status <> 'cancelled'
      and not exists (
        select 1 from private.admin_preorder_hidden h
        where h.source='native' and h.order_id=p.id::text
      )
  ) + (
    select count(*) from public.web_preorder_requests w
    where w.status <> 'cancelled'
      and not exists (
        select 1 from private.admin_preorder_hidden h
        where h.source='web' and h.order_id=w.id::text
      )
  ) into total;
  return total;
end;
$$;
revoke all on function public.admin_active_preorder_count(text)
from public, anon, authenticated;
grant execute on function public.admin_active_preorder_count(text) to service_role;
