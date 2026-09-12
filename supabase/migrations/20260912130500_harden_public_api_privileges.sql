-- Muhajeer Books production security hardening.
-- Keeps current customer/admin flows intact while removing unnecessary raw privileges.

-- Internal-only tables: clients use RPCs, not direct table access.
revoke all privileges on table public.app_installations from anon, authenticated;
revoke all privileges on table public.book_sync_tombstones from anon, authenticated;

-- Public catalog: anonymous users only need read access (RLS limits rows to active books).
revoke insert, update, delete, truncate, references, trigger on table public.books from anon;
revoke truncate, references, trigger on table public.books from authenticated;

-- Orders: public customers create orders and receive the insert result, but do not edit/delete directly.
revoke update, delete, truncate, references, trigger on table public.orders from anon;
revoke delete, truncate, references, trigger on table public.orders from authenticated;

-- Profiles: anonymous users do not access profiles; signed-in users only need SELECT in current app.
revoke all privileges on table public.profiles from anon;
revoke insert, delete, truncate, references, trigger on table public.profiles from authenticated;

-- Remove implicit PUBLIC execution from exposed RPCs while preserving explicit grants used by
-- the current app/bot. This prevents unrelated database roles from inheriting callable endpoints.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (
        p.proname like 'admin\_%' escape '\'
        or p.proname like 'bot\_%' escape '\'
        or p.proname like 'customer\_%' escape '\'
        or p.proname in ('register_app_install', 'is_admin')
      )
  loop
    execute format('revoke execute on function %s from public', r.fn);
  end loop;
end $$;

-- Internal helpers are backend-only APIs.
revoke execute on function public._secret_ok(text, text) from public, anon, authenticated;
revoke execute on function public._normalize_book_images_row() from public, anon, authenticated;
grant execute on function public._secret_ok(text, text) to service_role;
grant execute on function public._normalize_book_images_row() to service_role;

-- Safer defaults for FUTURE public objects. Existing grants are not changed by these statements.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete, truncate, references, trigger on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke usage, select, update on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
