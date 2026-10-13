-- A separate planned state for not-yet-on-sale books.
alter table public.books add column if not exists planned boolean not null default false;

create or replace function public.admin_set_book_planned(
  p_secret text, p_id uuid, p_planned boolean
) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $fn$
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
 update public.books
 set planned=coalesce(p_planned,false),
     is_active=case when coalesce(p_planned,false) then false else is_active end,
     preorder_enabled=case when coalesce(p_planned,false) then false else preorder_enabled end
 where id=p_id;
 if not found then raise exception 'Kitob topilmadi'; end if;
 return true;
end $fn$;
revoke all on function public.admin_set_book_planned(text,uuid,boolean)
 from public,anon,authenticated;
grant execute on function public.admin_set_book_planned(text,uuid,boolean)
 to service_role;
