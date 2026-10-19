-- Web-only: additive data, private durable notifications and guarded status changes.
-- Preserve the previous functions/settings/requests before changing their behavior.
create table private.web_preorder_backup_20261020 as
select now() as backed_up_at,
  (select jsonb_agg(to_jsonb(r)) from public.web_preorder_requests r) as requests,
  (select jsonb_agg(to_jsonb(s)) from public.web_preorder_settings s) as settings,
  (select jsonb_agg(jsonb_build_object('id',b.id,'preorder_enabled',b.preorder_enabled,
    'arrival',b.preorder_arrival_note,'min',b.preorder_deposit_min,'max',b.preorder_deposit_max)) from public.books b) as book_terms,
  (select jsonb_agg(pg_get_functiondef(p.oid)) from pg_proc p where p.oid in
    ('public.web_preorder_submit(jsonb)'::regprocedure,'public.admin_web_preorder_manage(text,text,jsonb)'::regprocedure)) as functions;
revoke all on private.web_preorder_backup_20261020 from public,anon,authenticated;
alter table private.web_preorder_backup_20261020 enable row level security;

alter table public.web_preorder_requests
  add column book_id uuid references public.books(id),
  add column book_image_url text not null default '',
  add column terms_token text not null default '',
  add column status_version integer not null default 1,
  add column status_note text not null default '';

create index web_preorder_requests_book_idx on public.web_preorder_requests(book_id) where book_id is not null;

create table private.web_preorder_events (
  id uuid primary key default gen_random_uuid(),
  preorder_id uuid not null references public.web_preorder_requests(id),
  version integer not null,
  audience text not null check(audience in ('customer','admin')),
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
  last_error text not null default '',
  unique(preorder_id,version,audience)
);
alter table private.web_preorder_events enable row level security;
revoke all on private.web_preorder_events from public,anon,authenticated;
create index web_preorder_events_retry_idx on private.web_preorder_events(created_at)
  where delivery_state='pending';

create function public.web_preorder_book_config(p_book_id uuid) returns jsonb
language sql security definer set search_path='' as $$
 select jsonb_build_object('book_id',b.id,'book_title',b.title,
  'book_image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url,''),
  'enabled',b.is_active and b.preorder_enabled,
  'arrival_note',coalesce(b.preorder_arrival_note,''),
  'deposit_amount',greatest(5000,b.preorder_deposit_min),
  'deposit_max',greatest(5000,b.preorder_deposit_min,b.preorder_deposit_max),
  'terms_token',md5(jsonb_build_array(b.id,b.title,b.image_url,b.thumbnail_url,b.is_active,
    b.preorder_enabled,b.preorder_arrival_note,b.preorder_deposit_min,b.preorder_deposit_max)::text),
  'revision',1,'batch_quantity',0)
 from public.books b where b.id=p_book_id and b.is_active;
$$;

create or replace function public.web_preorder_submit(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 c jsonb; old public.web_preorder_requests%rowtype;
 rid uuid := (p_request->>'id')::uuid;
 bid uuid := nullif(p_request->>'book_id','')::uuid;
 qty integer := (p_request->>'quantity')::integer;
 title text := trim(p_request->>'book_title'); cname text := trim(p_request->>'customer_name');
 phone text := regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
 book_path text := coalesce(p_request->>'book_image_path','');
 proof_path text := p_request->>'payment_proof_path';
 total integer := (p_request->>'deposit_amount')::integer; per_book integer;
begin
 if rid is null or qty is null or qty not between 1 and 20 or
   coalesce(length(cname),0) not between 2 and 80 or phone !~ '^010[0-9]{8}$' then
   raise exception 'Ism, telefon va miqdorni tekshiring.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
 select * into old from public.web_preorder_requests r where r.id=rid;
 if found then
   if old.phone is distinct from phone or old.quantity is distinct from qty or
     old.customer_name is distinct from cname or old.book_id is distinct from bid or
     (bid is null and (old.book_title is distinct from title or old.book_image_path is distinct from book_path)) or
     old.payment_proof_path is distinct from proof_path or old.deposit_amount is distinct from total then
     raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.'; end if;
   return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
 end if;
 if bid is null then
   perform 1 from public.web_preorder_settings where id for share;
   c:=public.web_preorder_config();
 else
   perform 1 from public.books where id=bid for share;
   c:=public.web_preorder_book_config(bid);
   title:=c->>'book_title'; book_path:='';
 end if;
 if c is null or (c->>'enabled')::boolean is not true or trim(coalesce(c->>'arrival_note',''))='' then
   raise exception 'Bu kitob uchun oldindan buyurtma qabuli hozircha yopiq. Avans yubormang.'; end if;
 if coalesce(length(title),0) not between 2 and 160 then raise exception 'Kitob nomini tekshiring.'; end if;
 if (bid is null and (p_request->>'revision')::bigint is distinct from (c->>'revision')::bigint) or
    (bid is not null and p_request->>'terms_token' is distinct from c->>'terms_token') then
   raise exception 'Sana yoki avans o‘zgargan. Shartlarni yangilab, qayta tekshiring.'; end if;
 if total is null or total % qty <> 0 then raise exception 'Avans summasini tekshiring.'; end if;
 per_book:=total/qty;
 if per_book not between (c->>'deposit_amount')::integer and coalesce((c->>'deposit_max')::integer,(c->>'deposit_amount')::integer) then
   raise exception 'Avans summasini tekshiring.'; end if;
 if proof_path is null or proof_path !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
    not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof_path) or
    (bid is null and (book_path !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') or
      not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=book_path))) then
   raise exception 'Kitob rasmi va to‘lov chekini yuklang.'; end if;
 insert into public.web_preorder_requests(id,book_id,customer_name,phone,book_title,book_image_path,
  book_image_url,payment_proof_path,quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,terms_token)
 values(rid,bid,cname,phone,title,book_path,coalesce(c->>'book_image_url',''),proof_path,qty,per_book,total,
  c->>'arrival_note',(c->>'revision')::bigint,coalesce(c->>'terms_token',''));
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false);
exception when unique_violation then
 raise exception 'Bu chek bo‘yicha buyurtma avval qabul qilingan. Administrator bilan tekshiring.';
end;
$$;

-- One status operation = one version, one inbox message and one durable push event.
create function private.web_preorder_changed() returns trigger
language plpgsql security definer set search_path='' as $$
declare eid uuid; v_title text; v_body text; v_secret text;
begin
 if tg_op='UPDATE' and old.status is not distinct from new.status then return new; end if;
 v_title:=case when tg_op='INSERT' then 'Oldindan buyurtma yuborildi'
  when new.status='accepted' then 'Oldindan buyurtma qabul qilindi'
  when new.status='arrived' then 'Buyurtma bergan kitobingiz keldi'
  when new.status='cancelled' then 'Oldindan buyurtma bekor qilindi'
  else 'Oldindan buyurtma qayta ko‘rib chiqilmoqda' end;
 v_body:=new.book_title||' ×'||new.quantity||'. '||
  case when new.status='cancelled' then 'Avans qaytarilishi bo‘yicha administrator bilan bog‘laning.'
       when new.status='arrived' then 'Yetkazish va qolgan to‘lovni kelishish uchun administrator bilan bog‘laning.'
       else 'Taxminiy kelishi: '||new.arrival_note||'. Avans: ₩'||new.deposit_amount||'.' end||
  case when new.status_note<>'' then ' Izoh: '||new.status_note else '' end;
 insert into private.web_preorder_events(preorder_id,version,audience,status,title,body)
 values(new.id,new.status_version,'customer',new.status,v_title,v_body) returning id into eid;
 insert into public.customer_push_messages(id,phone,title,body,kind,sent_at)
 values(eid,new.phone,v_title,v_body,'web_preorder_'||new.status,now());
 if tg_op='INSERT' then
  insert into private.web_preorder_events(preorder_id,version,audience,status,title,body)
  values(new.id,new.status_version,'admin',new.status,'Yangi oldindan buyurtma',
    new.book_title||' ×'||new.quantity||'. Avans cheki: ₩'||new.deposit_amount||'. Admin panelda tekshiring.');
 end if;
 perform private.web_preorder_retry();
 return new;
end;
$$;
create trigger web_preorder_changes after insert or update of status on public.web_preorder_requests
for each row execute function private.web_preorder_changed();

-- Internal worker uses canonical events and verified web recipients. No client-provided message/phone.
create function public.web_preorder_delivery(p_secret text,p_event_id uuid,p_result jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.web_preorder_events%rowtype; expected text; recipients jsonb; lease uuid; phone_value text;
begin
 select event_secret into expected from private.push_event_config where id;
 if expected is null or p_secret is distinct from expected then raise exception 'Ruxsat yo‘q'; end if;
 select * into e from private.web_preorder_events where id=p_event_id for update;
 if not found then raise exception 'Xabar topilmadi'; end if;
 if p_result is not null then
  if (p_result->>'claim_token')::uuid is distinct from e.claim_token then raise exception 'Yetkazish navbati o‘zgargan'; end if;
  update private.web_preorder_events set
    delivered_keys=ARRAY(select distinct unnest(e.delivered_keys||ARRAY(select jsonb_array_elements_text(coalesce(p_result->'delivered_keys','[]'))))),
    delivery_state=case when coalesce((p_result->>'failed')::integer,0)>0 then case when e.attempts>=8 then 'failed' else 'pending' end
      when coalesce((p_result->>'recipients')::integer,0)=0 and cardinality(e.delivered_keys)=0 then 'no_subscribers' else 'sent' end,
    last_error=left(coalesce(p_result->>'error',''),200),claim_until=now()+interval '1 minute'
    where id=e.id;
  return jsonb_build_object('ok',true);
 end if;
 if e.delivery_state<>'pending' or e.attempts>=8 or e.claim_until>now() then return jsonb_build_object('skip',true); end if;
 select r.phone into phone_value from public.web_preorder_requests r where r.id=e.preorder_id;
 select coalesce(jsonb_agg(jsonb_build_object('endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth)),'[]') into recipients
 from public.push_subscriptions s
 where ((e.audience='admin' and s.admin_verified_at>=now()-interval '30 days') or
        (e.audience='customer' and regexp_replace(s.phone,'[^0-9]','','g')=phone_value))
   and md5(s.endpoint)<>all(e.delivered_keys);
 lease:=gen_random_uuid();
 update private.web_preorder_events set attempts=attempts+1,claim_token=lease,claim_until=now()+interval '5 minutes' where id=e.id;
 return jsonb_build_object('claim_token',lease,'title',e.title,'body',e.body,'audience',e.audience,
  'url',case when e.audience='admin' then '/?open=admin_orders' else '/?open=notifications' end,
  'tag','preorder-'||e.id,'subscriptions',recipients);
end;
$$;

create function private.web_preorder_retry() returns integer
language plpgsql security definer set search_path='' as $$
declare e record; v_secret text; n integer:=0;
begin
 select event_secret into v_secret from private.push_event_config where id;
 if coalesce(v_secret,'')='' then return 0; end if;
 for e in select id from private.web_preorder_events where delivery_state='pending' and attempts<8
  and (claim_until is null or claim_until<now()) and (queued_at is null or queued_at<now()-interval '1 minute') order by created_at limit 30
 loop
  perform net.http_post(url:='https://muhajeer-books-live-production.up.railway.app/api/push/preorder-event',
   body:=jsonb_build_object('event_id',e.id),headers:=jsonb_build_object('Content-Type','application/json','X-Muhajeer-Push-Secret',v_secret),timeout_milliseconds:=5000);
  update private.web_preorder_events set queued_at=now() where id=e.id;
  n:=n+1;
 end loop;
 return n;
end;
$$;
select cron.schedule('muhajeer_web_preorder_delivery','*/2 * * * *','select private.web_preorder_retry()');

-- Replace only the preorder admin function; all native/admin-rpc endpoints stay intact.
create or replace function public.admin_web_preorder_manage(p_secret text,p_action text,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.web_preorder_settings%rowtype; r public.web_preorder_requests%rowtype;
 enabled_value boolean; arrival text; amount integer; batch integer; target text; note_value text;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='settings' then return public.web_preorder_config();
 elsif p_action='save' then
  enabled_value:=(p_payload->>'enabled')::boolean; arrival:=trim(coalesce(p_payload->>'arrival_note',''));
  amount:=(p_payload->>'deposit_amount')::integer; batch:=(p_payload->>'batch_quantity')::integer;
  if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
    (enabled_value and arrival='') or amount not between 5000 and 10000000 or batch not between 0 and 100000 then
   raise exception 'Sana, avans va sonni tekshiring.'; end if;
  select * into s from public.web_preorder_settings where id for update;
  if (p_payload->>'revision')::bigint is distinct from s.revision then
   raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.'; end if;
  update public.web_preorder_settings set enabled=enabled_value,arrival_note=arrival,deposit_amount=amount,
   batch_quantity=batch,revision=revision+1,updated_at=now() where id;
  return public.web_preorder_config();
 elsif p_action='list' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select r.*,
    (select e.delivery_state from private.web_preorder_events e where e.preorder_id=r.id and e.audience='customer' order by version desc limit 1) as notification_state,
    (select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'created_at',h.created_at,'message',h.body) order by h.version desc),'[]') from private.web_preorder_events h where h.preorder_id=r.id and h.audience='customer') as history
    from public.web_preorder_requests r order by r.created_at desc limit 200) x),'[]');
 elsif p_action='status' then
  target:=p_payload->>'status'; note_value:=trim(coalesce(p_payload->>'note',''));
  if target is null or target not in ('waiting','accepted','arrived','cancelled') or length(note_value)>500 then raise exception 'Noto‘g‘ri holat'; end if;
  select * into r from public.web_preorder_requests q where q.id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Buyurtma topilmadi'; end if;
  if r.status=target then return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',true); end if;
  if (p_payload->>'version')::integer is distinct from r.status_version then raise exception 'Holat boshqa oynada o‘zgargan. Ro‘yxatni yangilang.'; end if;
  if (target='arrived' and r.status<>'accepted') or (r.status='cancelled' and target<>'waiting') or
    (target='waiting' and r.status<>'cancelled') then raise exception 'Avval buyurtmani qabul qiling yoki bekor qilingan buyurtmani qayta oching.'; end if;
  if target in ('cancelled','waiting') and length(note_value)<3 then raise exception 'Sababini yozing (kamida 3 belgi).'; end if;
  update public.web_preorder_requests q set status=target,status_note=note_value,status_version=q.status_version+1,updated_at=now() where q.id=r.id returning * into r;
  return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',false,'inbox_created',true);
 end if;
 raise exception 'Noto‘g‘ri amal';
end;
$$;
revoke all on function public.web_preorder_book_config(uuid),public.web_preorder_delivery(text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.web_preorder_book_config(uuid),public.web_preorder_delivery(text,uuid,jsonb) to service_role;
revoke all on function private.web_preorder_changed(),private.web_preorder_retry() from public,anon,authenticated;
