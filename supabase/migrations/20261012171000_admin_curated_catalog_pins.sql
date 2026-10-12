-- Curated customer catalogue: up to sixty admin-selected books appear first.
alter table public.books add column if not exists catalog_pin_rank integer;

create or replace function public.admin_set_catalog_pins(p_secret text,p_ids uuid[])
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Unauthorized'; end if;
 if coalesce(array_length(p_ids,1),0)>60 then raise exception 'At most 60 pinned books'; end if;
 if (select count(distinct x) from unnest(coalesce(p_ids,'{}'::uuid[])) x) <> coalesce(array_length(p_ids,1),0)
 then raise exception 'Duplicate book'; end if;
 if exists(select 1 from unnest(coalesce(p_ids,'{}'::uuid[])) x left join public.books b on b.id=x where b.id is null or not b.is_active)
 then raise exception 'Inactive or unknown book'; end if;
 update public.books set catalog_pin_rank=null where catalog_pin_rank is not null;
 update public.books b set catalog_pin_rank=u.idx
 from unnest(coalesce(p_ids,'{}'::uuid[])) with ordinality as u(id,idx)
 where b.id=u.id;
 get diagnostics n=row_count;
 return n;
end $$;
revoke all on function public.admin_set_catalog_pins(text,uuid[]) from public,anon,authenticated;
grant execute on function public.admin_set_catalog_pins(text,uuid[]) to service_role;

do $x$ declare stmt text; begin
 stmt:=pg_get_functiondef('public.customer_catalog_delta(timestamptz)'::regprocedure);
 if strpos(stmt,'''catalog_pin_rank'',b.catalog_pin_rank')=0 then
  if strpos(stmt,'''restocked_at'',b.restocked_at')=0 then raise exception 'missing restock column'; end if;
  execute replace(stmt,'''restocked_at'',b.restocked_at','''restocked_at'',b.restocked_at,''catalog_pin_rank'',b.catalog_pin_rank');
 end if;
end $x$;
