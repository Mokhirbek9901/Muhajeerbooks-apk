
-- Preorder push: verified admin APNs/FCM and device-owned customer APNs/FCM.
-- Tokens never flow to public clients; the worker authenticates using an
-- internal event secret and ownership is derived from device/preorder links.
create table if not exists private.native_preorder_push_events (
 id uuid primary key default gen_random_uuid(),
 preorder_id bigint not null references public.preorders(id),
 audience text not null check (audience in ('admin','customer')),
 status text not null,
 title text not null,
 body text not null,
 created_at timestamptz not null default now(),
 attempts integer not null default 0,
 claim_token uuid,
 claim_until timestamptz,
 queued_at timestamptz,
 delivery_state text not null default 'pending',
 delivered_keys text[] not null default '{}',
 last_error text not null default ''
);
alter table private.native_preorder_push_events enable row level security;
revoke all on private.native_preorder_push_events from public,anon,authenticated;
create index if not exists native_preorder_push_retry_idx
 on private.native_preorder_push_events (created_at)
 where delivery_state='pending';

create or replace function public.event_preorder_native_recipients(
 p_event_secret text,p_source text,p_reference text,p_audience text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare apns jsonb; android jsonb;
begin
 if not exists(select 1 from private.push_event_config
               where id=true and event_secret=p_event_secret)
 then raise exception 'Ruxsat yo‘q'; end if;
 if p_source not in ('web','native') or p_audience not in ('admin','customer')
   or length(coalesce(p_reference,'')) not between 1 and 40
 then raise exception 'Xabar ma’lumoti noto‘g‘ri'; end if;
 if (p_source='web' and not exists(
      select 1 from private.web_preorder_events e
      where e.preorder_id::text=p_reference and e.audience=p_audience))
    or (p_source='native' and not exists(
      select 1 from private.native_preorder_push_events e
      where e.preorder_id::text=p_reference and e.audience=p_audience))
 then raise exception 'Tasdiqlanmagan oldindan buyurtma hodisasi'; end if;

 if p_audience='admin' then
   select coalesce(jsonb_agg(t.token),'[]'::jsonb) into apns
     from (select distinct lower(a.token) token
             from private.admin_apns_devices a where a.active) t;
   select coalesce(jsonb_agg(t.token),'[]'::jsonb) into android
     from (select distinct f.token from private.native_fcm_devices f
             where f.admin_verified_at>=now()-interval '30 days') t;
 else
   select coalesce(jsonb_agg(t.token),'[]'::jsonb) into apns
     from (select distinct lower(a.token) token
         from private.customer_device_preorders o
         join private.customer_device_profiles d on d.id=o.device_id
         join private.customer_device_apns a on a.device_id=d.id
        where o.source=p_source and o.reference=p_reference
          and d.revoked_at is null) t;
   select coalesce(jsonb_agg(t.token),'[]'::jsonb) into android
     from (select distinct f.token
         from private.customer_device_preorders o
         join private.customer_device_profiles d on d.id=o.device_id
         join private.native_fcm_devices f on f.device_profile_id=d.id
        where o.source=p_source and o.reference=p_reference
          and d.revoked_at is null and f.customer_opted_in) t;
 end if;
 return jsonb_build_object('apns',apns,'fcm',android);
end $$;
revoke all on function public.event_preorder_native_recipients(text,text,text,text)
 from public,anon,authenticated;
grant execute on function public.event_preorder_native_recipients(text,text,text,text)
 to service_role;

create or replace function public.native_preorder_delivery(
 p_secret text,p_event_id uuid,p_result jsonb default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.native_preorder_push_events%rowtype; lease uuid;
begin
 if not exists (select 1 from private.push_event_config
                where id=true and event_secret=p_secret)
 then raise exception 'Ruxsat yo‘q'; end if;
 select * into e from private.native_preorder_push_events
  where id=p_event_id for update;
 if not found then raise exception 'Hodisa topilmadi'; end if;
 if p_result is not null then
   if (p_result->>'claim_token')::uuid is distinct from e.claim_token
   then raise exception 'Push navbati boshqa ishchida'; end if;
   update private.native_preorder_push_events set
    delivered_keys=array(select distinct unnest(
      e.delivered_keys || array(
        select jsonb_array_elements_text(coalesce(p_result->'delivered_keys','[]'::jsonb))))),
    delivery_state=case
      when coalesce((p_result->>'failed')::integer,0)>0
        then case when e.attempts>=8 then 'failed' else 'pending' end
      when coalesce((p_result->>'recipients')::integer,0)=0
         and cardinality(e.delivered_keys)=0 then 'no_subscribers'
      else 'sent' end,
    last_error=left(coalesce(p_result->>'error',''),200),
    claim_until=now()+interval '1 minute'
    where id=e.id;
   return jsonb_build_object('ok',true);
 end if;
 if e.delivery_state<>'pending' or e.attempts>=8 or e.claim_until>now()
 then return jsonb_build_object('skip',true); end if;
 lease:=gen_random_uuid();
 update private.native_preorder_push_events
 set attempts=attempts+1,claim_token=lease,claim_until=now()+interval '5 minutes'
 where id=e.id;
 return jsonb_build_object('claim_token',lease,'audience',e.audience,
  'source','native','reference',e.preorder_id::text,'title',e.title,
  'body',e.body,'delivered_keys',to_jsonb(e.delivered_keys));
end $$;
revoke all on function public.native_preorder_delivery(text,uuid,jsonb)
 from public,anon,authenticated;
grant execute on function public.native_preorder_delivery(text,uuid,jsonb) to service_role;

create or replace function private.native_preorder_retry() returns integer
language plpgsql security definer set search_path='' as $$
declare e record; secret_value text; n integer:=0;
begin
 select event_secret into secret_value from private.push_event_config where id=true;
 if coalesce(secret_value,'')='' then return 0; end if;
 for e in select id from private.native_preorder_push_events
  where delivery_state='pending' and attempts<8
   and (claim_until is null or claim_until<now())
   and (queued_at is null or queued_at<now()-interval '1 minute')
  order by created_at limit 30 loop
   perform net.http_post(
    url:='https://muhajeer-books-live-production.up.railway.app/api/push/native-preorder-event',
    body:=jsonb_build_object('event_id',e.id),
    headers:=jsonb_build_object('Content-Type','application/json',
                                'X-Muhajeer-Push-Secret',secret_value),
    timeout_milliseconds:=5000);
   update private.native_preorder_push_events set queued_at=now() where id=e.id;
   n:=n+1;
 end loop;
 return n;
end $$;

create or replace function private.native_preorder_push_changed() returns trigger
language plpgsql security definer set search_path='' as $$
declare title_text text;
begin
 if tg_op='UPDATE' and new.status is not distinct from old.status then
   return new;
 end if;
 title_text:=case
   when tg_op='INSERT' then 'Oldindan zakaz yuborildi'
   when new.status='accepted' then 'Oldindan zakaz qabul qilindi'
   when new.status='arrived' then 'Oldindan zakazdagi kitob keldi'
   when new.status='cancelled' then 'Oldindan zakaz bekor qilindi'
   else 'Oldindan zakaz holati yangilandi' end;
 insert into private.native_preorder_push_events
   (preorder_id,audience,status,title,body)
 values (new.id,'customer',new.status,title_text,
   'Profil → Oldindan zakazlarim bo‘limida buyurtma holatini tekshiring.');
 if tg_op='INSERT' then
   insert into private.native_preorder_push_events
    (preorder_id,audience,status,title,body)
   values(new.id,'admin',new.status,'Yangi oldindan zakaz',
          'Admin paneldan avans chekini va oldindan buyurtmani tekshiring.');
 end if;
 perform private.native_preorder_retry();
 return new;
end $$;
drop trigger if exists native_preorder_push_changed on public.preorders;
create trigger native_preorder_push_changed
 after insert or update of status on public.preorders
 for each row execute function private.native_preorder_push_changed();
select cron.schedule('muhajeer_native_preorder_delivery','*/2 * * * *',
 'select private.native_preorder_retry()');

-- Add event order identity to existing, durable web outbox response without
-- changing the established payment/order handling or queued push rows.
do $$
declare def text;
  old_fragment text := '''tag'',''preorder-''||e.id,''subscriptions'',recipients);';
  new_fragment text := '''tag'',''preorder-''||e.id,''subscriptions'',recipients,''reference'',e.preorder_id::text,''source'',''web'',''delivered_keys'',to_jsonb(e.delivered_keys));';
begin
 def:=pg_get_functiondef('public.web_preorder_delivery(text,uuid,jsonb)'::regprocedure);
 if position(old_fragment in def)=0 then
   raise exception 'Web preorder outbox schema changed; refusing unsafe replacement';
 end if;
 execute replace(def,old_fragment,new_fragment);
end $$;
