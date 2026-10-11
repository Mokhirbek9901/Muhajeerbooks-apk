-- Only the owner's personal reading library, separate from costs, catalog and sales.
begin;
create table if not exists public.yordamchi_reading_library (
 id boolean primary key default true check(id),
 version bigint not null default 0,
 payload jsonb,
 updated_at timestamptz not null default now()
);
alter table public.yordamchi_reading_library enable row level security;
revoke all on public.yordamchi_reading_library from public, anon, authenticated;
grant select,insert,update on public.yordamchi_reading_library to service_role;
insert into public.yordamchi_reading_library(id) values(true) on conflict do nothing;
create or replace function public.yordamchi_save_reading_library(p_version bigint,p_payload jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare result jsonb;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>12000000 then raise exception 'Invalid library'; end if;
 update public.yordamchi_reading_library set payload=p_payload,version=version+1,updated_at=now()
 where id=true and version=p_version
 returning jsonb_build_object('version',version,'payload',payload) into result;
 if result is null then raise exception using errcode='40001',message='Library changed on another device'; end if;
 return result;
end $$;
revoke all on function public.yordamchi_save_reading_library(bigint,jsonb) from public,anon,authenticated;
grant execute on function public.yordamchi_save_reading_library(bigint,jsonb) to service_role;
commit;
