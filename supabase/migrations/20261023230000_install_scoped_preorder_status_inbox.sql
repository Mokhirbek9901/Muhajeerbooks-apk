-- Installation-scoped preorder timeline and customer in-app notifications.
-- Do not use unverified telephone numbers as proof of ownership.
create table if not exists private.customer_preorder_events (
 id bigint generated always as identity primary key,
 preorder_id bigint not null references public.preorders(id) on delete restrict,
 event_type text not null check(event_type in ('submitted','accepted','arrived','cancelled','reopened')),
 title text not null,
 message text not null,
 created_at timestamptz not null default now(),
 unique(preorder_id,event_type)
);
revoke all on private.customer_preorder_events from public,anon,authenticated;

create or replace function private.preorder_status_customer_notice()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_kind text; v_title text; v_text text;
begin
 if tg_op='INSERT' then
    v_kind:='submitted';
 elsif new.status is not distinct from old.status then
    return new;
 elsif new.status='accepted' then
    v_kind:='accepted';
 elsif new.status='arrived' then
    v_kind:='arrived';
 elsif new.status='cancelled' then
    v_kind:='cancelled';
 elsif new.status='waiting' and old.status='cancelled' then
    v_kind:='reopened';
 else
    return new;
 end if;
 v_title:=case v_kind
  when 'submitted' then 'Oldindan zakaz yuborildi'
  when 'accepted' then 'Oldindan zakazingiz qabul qilindi ✅'
  when 'arrived' then 'Kitobingiz keldi 📚'
  when 'cancelled' then 'Oldindan zakaz bekor qilindi'
  else 'Oldindan zakaz qayta ko‘rib chiqilmoqda' end;
 v_text:=case v_kind
  when 'submitted' then 'Zakazingiz qabul qilinishini kutmoqda. Holatini «Oldindan zakazlarim» bo‘limida ko‘ring.'
  when 'accepted' then 'Oldindan zakazingiz tasdiqlandi. Band qilingan kitob va keyingi bosqichni «Oldindan zakazlarim» bo‘limida tekshiring.'
  when 'arrived' then 'Kitobingiz keldi! Admin izohi, avans va qolgan to‘lovni «Oldindan zakazlarim» bo‘limida ko‘ring.'
  when 'cancelled' then 'Oldindan zakazingiz bekor qilindi. Batafsil ma’lumot uchun do‘kon bilan bog‘laning.'
  else 'Oldindan zakazingiz qayta ko‘rib chiqilmoqda.' end;
 insert into private.customer_preorder_events(
   preorder_id,event_type,title,message)
 values(new.id,v_kind,v_title,v_text)
 on conflict(preorder_id,event_type) do nothing;
 return new;
end;
$$;

drop trigger if exists preorder_customer_notice_on_status on public.preorders;
create trigger preorder_customer_notice_on_status
after insert or update of status on public.preorders
for each row execute function private.preorder_status_customer_notice();

-- Backfill the accepted/arrived state for existing clients, without changing
-- status or resending any device push. Historical timestamps stay historical.
insert into private.customer_preorder_events(
 preorder_id,event_type,title,message,created_at)
select p.id,'submitted','Oldindan zakaz yuborildi',
 'Zakazingiz yuborilgan. Holatini «Oldindan zakazlarim» bo‘limida tekshiring.',
 p.created_at
from public.preorders p
where not exists(select 1 from private.admin_preorder_hidden h
                  where h.source='native' and h.order_id=p.id::text)
on conflict(preorder_id,event_type) do nothing;

insert into private.customer_preorder_events(
 preorder_id,event_type,title,message,created_at)
select p.id,
 case when p.status='arrived' then 'arrived' else 'accepted' end,
 case when p.status='arrived' then 'Kitobingiz keldi 📚'
      else 'Oldindan zakazingiz qabul qilindi ✅' end,
 case when p.status='arrived' then 'Qolgan to‘lovni «Oldindan zakazlarim» bo‘limida tekshiring.'
      else 'Zakazingiz tasdiqlangan. «Oldindan zakazlarim» bo‘limiga o‘ting.' end,
 coalesce((select max(e.changed_at) from private.admin_preorder_status_events e
           where e.preorder_id=p.id and e.new_status=p.status),p.created_at)
from public.preorders p
where p.status in ('accepted','arrived') and
 not exists(select 1 from private.admin_preorder_hidden h
  where h.source='native' and h.order_id=p.id::text)
on conflict(preorder_id,event_type) do nothing;

create or replace function public.customer_preorder_event_list(
 p_install_id text,p_limit integer default 60
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_events jsonb;
begin
 if length(trim(coalesce(p_install_id,'')))<12 or length(p_install_id)>120
    or coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma yoki sahifalash noto‘g‘ri';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.id desc),
                 '[]'::jsonb) into v_events from (
   select e.id,e.preorder_id,e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=trim(p_install_id)
      and not exists(select 1 from private.admin_preorder_hidden a
       where a.source='native' and a.order_id=p.id::text)
   order by e.created_at desc,e.id desc limit p_limit
 ) t;
 return v_events;
end;
$$;
revoke all on function public.customer_preorder_event_list(text,integer)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_event_list(text,integer)
 to service_role;
