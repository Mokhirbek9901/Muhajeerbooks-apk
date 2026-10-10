-- Separate, service-only storage. Never updates catalog books or sales history.
create table if not exists public.yordamchi_device_list (
 id boolean primary key default true check(id),
 version bigint not null default 0,
 payload jsonb,
 updated_at timestamptz not null default now()
);
alter table public.yordamchi_device_list enable row level security;
revoke all on public.yordamchi_device_list from public, anon, authenticated;
grant select,insert,update on public.yordamchi_device_list to service_role;
insert into public.yordamchi_device_list(id) values(true) on conflict do nothing;
create or replace function public.yordamchi_save_device_list(p_version bigint,p_payload jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare result jsonb;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>1000000 then raise exception 'Invalid list'; end if;
 update public.yordamchi_device_list set payload=p_payload,version=version+1,updated_at=now()
 where id=true and version=p_version
 returning jsonb_build_object('version',version,'payload',payload) into result;
 if result is null then raise exception using errcode='40001',message='List changed on another device'; end if;
 return result;
end $$;
revoke all on function public.yordamchi_save_device_list(bigint,jsonb) from public,anon,authenticated;
grant execute on function public.yordamchi_save_device_list(bigint,jsonb) to service_role;
