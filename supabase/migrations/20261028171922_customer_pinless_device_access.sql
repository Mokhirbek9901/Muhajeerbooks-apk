-- Existing bookings keep their contacts and advances; new device bookings
-- require an Instagram username so the shop can contact the buyer on arrival.
alter table public.preorders add column if not exists instagram_handle text not null default '';
alter table public.web_preorder_requests add column if not exists instagram_handle text not null default '';

-- Staged PINless customer access. No client knows the short-lived compatibility
-- session. A phone is contact data; only a random device secret authorizes access.
create table if not exists private.customer_device_profiles (
 id uuid primary key default gen_random_uuid(), secret_hash text not null unique,
 install_id text not null, full_name text not null, display_phone text not null,
 phone_key text not null, legacy_scope boolean not null default false,
 revoked_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists customer_device_profiles_install on private.customer_device_profiles(install_id);
create table if not exists private.customer_device_orders (
 order_id uuid primary key references public.orders(id),
 device_id uuid not null references private.customer_device_profiles(id)
);
create index if not exists customer_device_orders_device on private.customer_device_orders(device_id);
-- Explicit ownership survives a contact edit but never follows a typed phone.
create table if not exists private.customer_device_preorders (
 source text not null check(source in ('native','web')), reference text not null,
 device_id uuid not null references private.customer_device_profiles(id),
 primary key(source,reference)
);
create index if not exists customer_device_preorders_device on private.customer_device_preorders(device_id);
create table if not exists private.customer_device_recovery (
 id uuid primary key default gen_random_uuid(), device_id uuid not null references private.customer_device_profiles(id),
 note text not null, status text not null default 'pending' check(status in ('pending','resolved','rejected')),
 verification_note text not null default '', created_at timestamptz not null default now(), resolved_at timestamptz
);
create unique index if not exists customer_device_recovery_pending on private.customer_device_recovery(device_id) where status='pending';
create table if not exists private.customer_device_quotes (
 quote_id uuid primary key references private.release_checkout_quotes(id),
 device_id uuid not null references private.customer_device_profiles(id)
);
create index if not exists customer_device_quotes_device on private.customer_device_quotes(device_id);
create table if not exists private.customer_device_receipts (
 path text primary key, device_id uuid not null references private.customer_device_profiles(id)
);
create index if not exists customer_device_receipts_device on private.customer_device_receipts(device_id);
create table if not exists private.customer_device_push (
 endpoint text primary key, device_id uuid not null references private.customer_device_profiles(id)
);
create index if not exists customer_device_push_device on private.customer_device_push(device_id);
alter table private.customer_device_preorders enable row level security;
alter table private.customer_device_recovery enable row level security;
revoke all on private.customer_device_preorders,private.customer_device_recovery from public,anon,authenticated;
alter table private.customer_device_profiles enable row level security;
alter table private.customer_device_orders enable row level security;
alter table private.customer_device_quotes enable row level security;
alter table private.customer_device_receipts enable row level security;
alter table private.customer_device_push enable row level security;
revoke all on private.customer_device_profiles,private.customer_device_orders,
 private.customer_device_quotes,private.customer_device_receipts,private.customer_device_push from public,anon,authenticated;

create or replace function private.customer_device(p_session text)
returns private.customer_device_profiles language plpgsql security definer set search_path='' as $$
declare d private.customer_device_profiles;
begin
 if coalesce(p_session,'') !~ '^device:[a-f0-9]{64}$' then raise exception 'Qurilma kirishi tasdiqlanmadi'; end if;
 select * into d from private.customer_device_profiles
 where secret_hash=encode(extensions.digest(substr(p_session,8),'sha256'),'hex') and revoked_at is null;
 if not found then raise exception 'Qurilma kirishi tasdiqlanmadi'; end if;
 return d;
end $$;

create or replace function public.customer_device_bootstrap(p_secret text,p_install_id text,p_name text,p_phone text,p_previous_session text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.customer_device_profiles; k text:=public._customer_phone_key(p_phone); h text; proven boolean:=false;
begin
 if coalesce(p_secret,'') !~ '^[a-f0-9]{64}$' or length(trim(coalesce(p_install_id,''))) not between 12 and 120
  or length(trim(coalesce(p_name,''))) not between 2 and 80 or length(k) not between 9 and 13 then
  raise exception 'Ism, telefon yoki qurilma ma’lumoti noto‘g‘ri'; end if;
 h:=encode(extensions.digest(p_secret,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('customer-device:'||h,29));
 select * into d from private.customer_device_profiles where secret_hash=h for update;
 if found then
  if d.revoked_at is not null or d.phone_key<>k or d.install_id<>trim(p_install_id) then raise exception 'Yangi qurilma profili kerak'; end if;
  update private.customer_device_profiles set full_name=trim(p_name),display_phone=trim(p_phone) where id=d.id returning * into d;
 else
  -- Upgrade only a valid session belonging to this exact installation. Typed
  -- names, phones, installation IDs and expired PIN sessions grant no full scope.
  proven:=private.pin_session_phone(p_previous_session)=k and exists(
   select 1 from private.customer_pin_sessions s where s.token_hash=encode(extensions.digest(p_previous_session,'sha256'),'hex')
    and s.install_id=trim(p_install_id) and s.expires_at>now());
  insert into private.customer_device_profiles(secret_hash,install_id,full_name,display_phone,phone_key,legacy_scope)
   values(h,trim(p_install_id),trim(p_name),trim(p_phone),k,coalesce(proven,false)) returning * into d;
  -- Backing row for the existing trusted pricing/stock ledger. The hash is of
  -- an unguessable random secret, never a generated four-digit customer PIN.
  insert into private.customer_pin_profiles(phone_key,display_phone,full_name,pin_hash)
   values(k,trim(p_phone),trim(p_name),extensions.crypt(encode(extensions.gen_random_bytes(32),'hex'),extensions.gen_salt('bf')))
   on conflict(phone_key) do nothing;
 end if;
 if coalesce(proven,false) then
  insert into private.customer_device_orders(order_id,device_id)
   select order_id,d.id from private.release_order_owners x where x.phone_key=k on conflict do nothing;
  insert into private.customer_device_preorders(source,reference,device_id)
   select 'native',p.id::text,d.id from public.preorders p where public._customer_phone_key(p.phone)=k and exists(
    select 1 from private.customer_pin_devices x where x.phone_key=k and x.install_id=p.install_id)
   union all select 'web',w.id::text,d.id from public.web_preorder_requests w where public._customer_phone_key(w.phone)=k and (
    exists(select 1 from private.customer_pin_devices x where x.phone_key=k and x.install_id=w.install_id)
    or (w.install_id is null and exists(select 1 from private.customer_pin_profiles x where x.phone_key=k and lower(trim(x.full_name))=lower(trim(w.customer_name)))))
   on conflict do nothing;
 end if;
 return jsonb_build_object('valid',true,'name',d.full_name,'phone',d.display_phone,'legacy_scope',d.legacy_scope);
end $$;

create or replace function private.customer_device_owns_preorder(d private.customer_device_profiles,p_source text,p_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if p_source not in ('native','web') then return false; end if;
 r:=private.release_preorder_context(p_source,p_id);
 if r is null or public._customer_phone_key(r->>'phone')<>d.phone_key then return false; end if;
 if exists(select 1 from private.customer_device_preorders x where x.source=p_source and x.reference=p_id and x.device_id=d.id) then return true; end if;
 return false;
end $$;

create or replace function private.customer_device_owns_order(d private.customer_device_profiles,p_id uuid)
returns boolean language sql security definer set search_path='' as $$
 select exists(select 1 from private.customer_device_orders x where x.order_id=p_id and x.device_id=d.id)

 or exists(select 1 from private.release_preorder_invoices i where i.converted_order_id=p_id
  and private.customer_device_owns_preorder(d,i.source,i.reference))
$$;

-- Fixed allowlist + pg_proc-typed named arguments. No arbitrary SQL, schema,
-- function name or type comes from the caller. Defaults remain SQL defaults.
create or replace function private.customer_device_call(p_action text,p_params jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; a text; args text:=''; arg_type text; pos integer; result jsonb;
begin
 if p_action<>all(array[
  'customer_pin_preorders','customer_release_preorder','customer_release_quote','customer_release_order',
  'customer_release_receipt','customer_release_apns','customer_web_preorder_checkout','customer_web_preorder_delivery',
  'customer_preorder_submit','customer_preorder_balance_list','customer_preorder_discovery','customer_preorder_activity_list',
  'customer_preorder_event_list','customer_book_review_submit','web_preorder_submit','web_preorder_submit_multi']) then
  raise exception 'Amalga ruxsat yo‘q'; end if;
 select p.* into strict f from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname=p_action and p.prokind='f';
 for a in select jsonb_object_keys(p_params) loop
  pos:=array_position(f.proargnames,a);
  if pos is null or pos>f.pronargs then raise exception 'So‘rov maydoni noto‘g‘ri'; end if;
  arg_type:=pg_catalog.format_type(f.proargtypes[pos-1],null);
  if args<>'' then args:=args||','; end if;
  if arg_type='jsonb' then args:=args||format('%I => ($1->%L)',a,a);
  elsif arg_type='uuid[]' then args:=args||format('%I => ARRAY(select jsonb_array_elements_text($1->%L))::uuid[]',a,a);
  else args:=args||format('%I => ($1->>%L)::%s',a,a,arg_type); end if;
 end loop;
 if f.proretset then
  execute format('select coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) from public.%I(%s) r',p_action,args) into result using p_params;
 else execute format('select to_jsonb(public.%I(%s))',p_action,args) into result using p_params; end if;
 return result;
end $$;

create or replace function public.customer_device_dispatch(p_device_session text,p_action text,p_params jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.customer_device_profiles:=private.customer_device(p_device_session); p jsonb:=coalesce(p_params,'{}');
 t text; th text; result jsonb; row jsonb; r record; oid uuid; qid uuid; path text; source text; reference text;
 added_device integer:=0; needs_session boolean:=false; compat_install text; instagram text;
begin
 if jsonb_typeof(p)<>'object' or length(p::text)>100000 then raise exception 'So‘rov juda katta'; end if;
 if p_action in ('customer_preorder_submit','web_preorder_submit','web_preorder_submit_multi') then
  instagram:=regexp_replace(trim(coalesce(case when p_action='customer_preorder_submit' then p->>'p_instagram_handle' else p->'p_request'->>'instagram_handle' end,'')),'^@','');
  if instagram !~ '^[A-Za-z0-9._]{1,30}$' then raise exception 'Instagram username kiriting: @username'; end if;
  p:=p-'p_instagram_handle';
 end if;
 -- Unknown operations fail before a compatibility session is created.
 if p_action<>all(array[
 'customer_device_recovery_request','customer_pin_profile','customer_pin_logout','customer_pin_preorders',
 'customer_release_preorder','customer_release_preorders','customer_release_link_orders','customer_release_my_orders',
 'customer_release_quote','customer_release_order','customer_release_inbox','customer_release_push_subscribe',
 'customer_release_receipt','customer_release_apns','customer_release_delete_profile','customer_release_reviews',
 'customer_release_review_action','customer_web_preorder_checkout','customer_web_preorder_delivery',
 'customer_preorder_submit','customer_preorder_balance_list','customer_preorder_discovery','customer_preorder_activity_list',
 'customer_preorder_event_list','customer_book_review_submit','web_preorder_submit','web_preorder_submit_multi']) then raise exception 'Amalga ruxsat yo‘q'; end if;
 if p_action='customer_device_recovery_request' then
  if length(trim(coalesce(p->>'p_note',''))) not between 10 and 500 then raise exception 'Eski buyurtma va bog‘lanish ma’lumotini yozing'; end if;
  insert into private.customer_device_recovery(device_id,note) values(d.id,trim(p->>'p_note'))
   on conflict(device_id) where status='pending' do update set note=excluded.note returning id into oid;
  return jsonb_build_object('requested',true,'request_id',oid);
 end if;
 if p_action='customer_pin_profile' then return jsonb_build_object('valid',true,'name',d.full_name,'phone',d.display_phone); end if;
 if p_action in ('customer_pin_logout','customer_release_delete_profile') then
  update private.customer_device_profiles set revoked_at=now() where id=d.id;
  update private.customer_apns_devices set opted_in=false where install_id=d.install_id;
  update public.push_subscriptions set phone='' where endpoint in(select endpoint from private.customer_device_push where device_id=d.id);
  delete from private.customer_device_push where device_id=d.id;
  if p_action='customer_release_delete_profile' then
   update private.customer_device_profiles set full_name='',display_phone='' where id=d.id;
  end if;
  return jsonb_build_object('deleted',true,'ok',true);
 end if;
 if p_action='customer_release_link_orders' then
  if jsonb_array_length(coalesce(p->'p_ids','[]'))>50 then raise exception 'Buyurtmalar soni noto‘g‘ri'; end if;
  for oid in select jsonb_array_elements_text(coalesce(p->'p_ids','[]'))::uuid loop
   if exists(select 1 from public.orders o where o.id=oid and public._customer_phone_key(o.phone)=d.phone_key and (
    (length(coalesce(p->'p_proofs'->>oid::text,''))>=20 and o.payment_proof_path=p->'p_proofs'->>oid::text))) then
    insert into private.customer_device_orders(order_id,device_id) values(oid,d.id) on conflict do nothing;
   end if;
  end loop;
  return 'true';
 end if;
 if p_action='customer_release_my_orders' then
  select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at desc),'[]') into result from public.orders o
   where private.customer_device_owns_order(d,o.id); return result;
 end if;
 if p_action='customer_release_inbox' then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.sent_at desc),'[]') into result from (
   select m.id,m.title,m.body,m.sent_at,'global'::text kind,null::bigint order_number,null::uuid order_id
    from public.push_messages m where m.sent_at is not null
   union all select m.id,m.title,m.body,m.sent_at,m.kind,m.order_number,m.order_id from public.customer_push_messages m
    where private.customer_device_owns_order(d,m.order_id)
   order by sent_at desc limit least(greatest(coalesce((p->>'p_limit')::integer,100),1),100)
  ) x; return result;
 end if;
 if p_action='customer_release_push_subscribe' then
  perform private.release_push_subscribe_base(p->>'p_endpoint',p->>'p_p256dh',p->>'p_auth',coalesce(p->>'p_user_agent',''),d.display_phone);
  insert into private.customer_device_push values(p->>'p_endpoint',d.id) on conflict(endpoint) do update set device_id=excluded.device_id;
  return 'true';
 end if;
 if p_action='customer_release_review_action' and p->>'p_action'='unblock_all' then
  delete from private.release_review_blocks where phone_key='device:'||d.id::text; return 'true';
 end if;
 if p_action='customer_release_reviews' then
  select coalesce(jsonb_agg(jsonb_build_object('id',rv.id,'book_id',rv.book_id,'reviewer_name',rv.reviewer_name,
   'rating',rv.rating,'comment',rv.comment,'created_at',rv.created_at) order by rv.created_at desc),'[]') into result
   from public.book_reviews rv join public.orders o on o.id=rv.order_id where rv.book_id=(p->>'p_book_id')::uuid and rv.is_approved
    and not exists(select 1 from private.release_review_blocks b where b.phone_key='device:'||d.id::text and b.author_key=public._customer_phone_key(o.phone));
  return result;
 end if;
 if p_action='customer_release_review_action' then
  select public._customer_phone_key(o.phone) into path from public.book_reviews rv join public.orders o on o.id=rv.order_id where rv.id=(p->>'p_review_id')::uuid;
  if path is null then raise exception 'Sharh topilmadi'; end if;
  if p->>'p_action'='report' then
   if length(trim(coalesce(p->>'p_reason',''))) not between 3 and 500 then raise exception 'Shikoyat sababini kiriting'; end if;
   insert into private.release_review_reports(review_id,phone_key,reason) values((p->>'p_review_id')::uuid,'device:'||d.id::text,trim(p->>'p_reason'))
    on conflict(review_id,phone_key) do update set reason=excluded.reason,status='pending';
  elsif p->>'p_action'='block' then insert into private.release_review_blocks values('device:'||d.id::text,path,now()) on conflict do nothing;
  elsif p->>'p_action'='unblock_all' then delete from private.release_review_blocks where phone_key='device:'||d.id::text;
  else raise exception 'Amal noto‘g‘ri'; end if; return 'true';
 end if;
 if p_action in ('customer_release_preorders','customer_pin_preorders','customer_preorder_discovery','customer_preorder_balance_list') then
  result:='[]';
  for r in select 'native'::text source,x.id::text reference,x.created_at from public.preorders x where public._customer_phone_key(x.phone)=d.phone_key
   union all select 'web',x.id::text,x.created_at from public.web_preorder_requests x where public._customer_phone_key(x.phone)=d.phone_key order by created_at desc loop
   if private.customer_device_owns_preorder(d,r.source,r.reference) and not exists(select 1 from private.admin_preorder_hidden h where h.source=r.source and h.order_id=r.reference) then
    perform private.release_preorder_ensure(r.source,r.reference);
    row:=private.release_preorder_detail(r.source,r.reference);
    if p_action='customer_preorder_balance_list' and r.source<>'native' then continue; end if;
    result:=result||jsonb_build_array(row||jsonb_build_object('ownership','device','invoice',row));
   end if;
  end loop; return result;
 end if;
 if p_action in ('customer_preorder_activity_list','customer_preorder_event_list') then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') into result from (
   select 'native:'||e.id::text id,'native'::text source,e.preorder_id::text preorder_id,e.event_type,e.title,e.message,e.created_at
    from private.customer_preorder_events e
    where private.customer_device_owns_preorder(d,'native',e.preorder_id::text)
     and not exists(select 1 from private.admin_preorder_hidden h where h.source='native' and h.order_id=e.preorder_id::text)
   union all select 'web:'||e.id::text,'web',e.preorder_id::text,e.status,'Oldindan zakaz holati o‘zgardi','Oldindan zakazlarim bo‘limini tekshiring.',e.created_at
    from private.web_preorder_events e where e.audience='customer' and private.customer_device_owns_preorder(d,'web',e.preorder_id::text)
     and not exists(select 1 from private.admin_preorder_hidden h where h.source='web' and h.order_id=e.preorder_id::text)
   order by created_at desc limit least(greatest(coalesce((p->>'p_limit')::integer,60),1),100)
  ) x; return result;
 end if;
 if p_action in ('customer_release_preorder','customer_web_preorder_checkout','customer_web_preorder_delivery') then
  source:=case when p_action='customer_release_preorder' then p->>'p_source' else 'web' end;
  reference:=case when p_action='customer_release_preorder' then p->>'p_id' else p->>'p_preorder_id' end;
  if not private.customer_device_owns_preorder(d,source,reference) then raise exception 'Bu buyurtma qurilmangizga tegishli emas'; end if;
  if (p_action='customer_release_preorder' and p->>'p_action'='proof') or (p_action='customer_web_preorder_checkout' and p->>'p_action'='proof') then
   path:=case when p_action='customer_release_preorder' then p->'p_payload'->>'path' else p->>'p_path' end;
   if not exists(select 1 from private.customer_device_receipts x where x.path=path and x.device_id=d.id) then raise exception 'Chek qurilmangizga tegishli emas'; end if;
  end if;
 end if;
 -- Preorder mutations reuse the existing ledger, including avans subtraction.
 -- Receipt paths and quote IDs are capabilities bound to the same device.
 if p_action='customer_preorder_submit' then
  if exists(select 1 from public.preorders x where x.install_id=d.install_id and x.book_id=(p->>'p_book_id')::uuid and x.status in ('waiting','contacted','accepted','arrived') and not private.customer_device_owns_preorder(d,'native',x.id::text)) then raise exception 'Avvalgi zakazni tiklash uchun do‘konga murojaat qiling'; end if;
  if not exists(select 1 from private.customer_device_receipts x where x.path=p->>'p_payment_proof_path' and x.device_id=d.id) then raise exception 'Chek qurilmangizga tegishli emas'; end if;
 end if;
 if p_action='customer_book_review_submit' then
  if not private.customer_device_owns_order(d,(p->>'p_order_id')::uuid) then raise exception 'Buyurtma sizga tegishli emas'; end if;
  p:=p||jsonb_build_object('p_phone',d.display_phone);
 end if;
 if p_action like 'customer_preorder_%' or p_action='customer_release_apns' then
  if p?'p_install_id' and p->>'p_install_id'<>d.install_id then raise exception 'Qurilma mos emas'; end if;
  p:=p||jsonb_build_object('p_install_id',d.install_id);
  if p_action='customer_preorder_submit' then p:=p||jsonb_build_object('p_phone',d.display_phone,'p_customer_name',d.full_name); end if;
 end if;
 if p_action in ('web_preorder_submit','web_preorder_submit_multi') then
  row:=p->'p_request';
  if coalesce(row->>'install_id','')<>d.install_id or public._customer_phone_key(row->>'phone')<>d.phone_key then raise exception 'Profil ma’lumotlari mos emas'; end if;
  -- Reject an existing UUID owned by another installation before legacy idempotency.
  if exists(select 1 from public.web_preorder_requests w where w.id=(row->>'id')::uuid and not private.customer_device_owns_preorder(d,'web',w.id::text)) then raise exception 'Buyurtma IDsi boshqa qurilmaga tegishli'; end if;
 end if;
 if p_action in ('customer_release_quote','customer_release_order') then
  if nullif(p->>'p_admin_token','') is not null then raise exception 'Admin kirishini alohida ishlating'; end if;
  if public._customer_phone_key(p->'p_order'->>'phone')<>d.phone_key then raise exception 'Profil telefonini ishlating'; end if;
 end if;
 if p_action='customer_release_order' then
  oid:=(p->'p_order'->>'id')::uuid; qid:=(p->>'p_quote_id')::uuid; path:=p->'p_order'->>'payment_proof_path';
  perform pg_advisory_xact_lock(hashtextextended('device-order:'||oid::text,29));
  if exists(select 1 from public.orders where id=oid) and not private.customer_device_owns_order(d,oid) then raise exception 'Buyurtma boshqa qurilmaga tegishli'; end if;
  if not exists(select 1 from private.customer_device_quotes x where x.quote_id=qid and x.device_id=d.id)
   or not exists(select 1 from private.customer_device_receipts x where x.path=path and x.device_id=d.id) then raise exception 'Hisob yoki chek qurilmangizga tegishli emas'; end if;
 end if;
 if p_action='customer_release_receipt' then
  path:=p->>'p_path';
  perform pg_advisory_xact_lock(hashtextextended('device-receipt:'||coalesce(path,''),29));
  if exists(select 1 from private.customer_device_receipts x where x.path=path and x.device_id<>d.id) then raise exception 'Chek boshqa qurilmaga tegishli'; end if;
 end if;
 -- Reuse validated price, stock, receipt and advance-ledger routines. The
 -- temporary session/device link exists only inside this transaction and is
 -- removed before returning. It is never sent to the application.
 select 'p_session'=any(proargnames) into needs_session from pg_catalog.pg_proc f join pg_catalog.pg_namespace n on n.oid=f.pronamespace
  where n.nspname='public' and f.proname=p_action;
 needs_session:=coalesce(needs_session,false) or p_action in ('web_preorder_submit','web_preorder_submit_multi');
 if needs_session then
  perform pg_advisory_xact_lock(hashtextextended('device-compat:'||d.phone_key||':'||d.install_id,29));
  t:=encode(extensions.gen_random_bytes(32),'hex'); th:=encode(extensions.digest(t,'sha256'),'hex');
  insert into private.customer_pin_sessions(token_hash,phone_key,install_id,expires_at) values(th,d.phone_key,d.install_id,now()+interval '1 minute');
  compat_install:=d.install_id;
  if source is not null then compat_install:=coalesce(nullif(private.release_preorder_context(source,reference)->>'install_id',''),d.install_id); end if;
  insert into private.customer_pin_devices(phone_key,install_id) values(d.phone_key,compat_install) on conflict do nothing;
  get diagnostics added_device=row_count;
  if p_action in ('web_preorder_submit','web_preorder_submit_multi') then p:=jsonb_set(p,'{p_request,session}',to_jsonb(t));
  else p:=p||jsonb_build_object('p_session',t); end if;
 end if;
 p:=p-'p_proofs';
 result:=private.customer_device_call(p_action,p);
 if p_action='customer_release_quote' then
  insert into private.customer_device_quotes values((result->>'quote_id')::uuid,d.id);
 elsif p_action='customer_release_order' then
  insert into private.customer_device_orders values((result->>'id')::uuid,d.id) on conflict do nothing;
 elsif p_action='customer_preorder_submit' then
  insert into private.customer_device_preorders values('native',result->>'id',d.id) on conflict do nothing;
  update public.preorders set instagram_handle=instagram where id=(result->>'id')::bigint;
 elsif p_action in ('web_preorder_submit','web_preorder_submit_multi') then
  insert into private.customer_device_preorders values('web',result->>'id',d.id) on conflict do nothing;
  update public.web_preorder_requests set instagram_handle=instagram where id=(result->>'id')::uuid;
 elsif p_action='customer_release_receipt' then
  insert into private.customer_device_receipts values(path,d.id) on conflict do nothing;
 end if;
 if needs_session then
  -- The web subscription is bound separately to the durable device, never t.
  delete from private.customer_pin_sessions where token_hash=th;
  if added_device>0 then delete from private.customer_pin_devices where phone_key=d.phone_key and install_id=compat_install; end if;
 end if;
 return result;
end $$;

revoke all on function private.customer_device(text),private.customer_device_owns_preorder(private.customer_device_profiles,text,text),
 private.customer_device_owns_order(private.customer_device_profiles,uuid),private.customer_device_call(text,jsonb),
 public.customer_device_bootstrap(text,text,text,text,text),public.customer_device_dispatch(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.customer_device_bootstrap(text,text,text,text,text),public.customer_device_dispatch(text,text,jsonb) to service_role;


-- No customer enters a code. The administrator independently verifies the
-- applicant, then grants access to this exact device request, with an audit note.
create or replace function public.admin_customer_device_recovery(p_secret text,p_action text,p_id uuid default null,p_verification_note text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare req private.customer_device_recovery; d private.customer_device_profiles; result jsonb;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]') into result from (
   select r.id,r.note,r.created_at,d.full_name,d.display_phone as phone_key,d.install_id
    from private.customer_device_recovery r join private.customer_device_profiles d on d.id=r.device_id
    where r.status='pending' and d.revoked_at is null order by r.created_at desc limit 200
  )x; return result;
 end if;
 select * into req from private.customer_device_recovery where id=p_id for update;
 if not found or req.status<>'pending' then raise exception 'Faol so‘rov topilmadi'; end if;
 select * into d from private.customer_device_profiles where id=req.device_id for update;
 if d.revoked_at is not null then raise exception 'Qurilma kirishi bekor qilingan'; end if;
 if p_action='approve' then
  if length(trim(coalesce(p_verification_note,''))) not between 10 and 500 then raise exception 'Shaxs va buyurtma qanday tekshirilganini yozing'; end if;
  -- Move existing records only. Future requests with the same contact phone
  -- remain isolated and require a separate verified recovery.
  insert into private.customer_device_orders(order_id,device_id)
   select id,d.id from public.orders o where public._customer_phone_key(o.phone)=d.phone_key
   on conflict(order_id) do update set device_id=excluded.device_id;
  insert into private.customer_device_preorders(source,reference,device_id)
   select 'native',id::text,d.id from public.preorders p where public._customer_phone_key(p.phone)=d.phone_key
   union all select 'web',id::text,d.id from public.web_preorder_requests w where public._customer_phone_key(w.phone)=d.phone_key
   on conflict(source,reference) do update set device_id=excluded.device_id;
  update private.customer_device_profiles set revoked_at=now() where phone_key=d.phone_key and id<>d.id;
  delete from private.customer_pin_sessions where phone_key=d.phone_key;
  update private.customer_apns_devices set opted_in=false where public._customer_phone_key(phone_digits)=d.phone_key;
  update public.push_subscriptions set phone='' where endpoint in(
   select p.endpoint from private.customer_device_push p join private.customer_device_profiles x on x.id=p.device_id where x.phone_key=d.phone_key and x.id<>d.id);
  update private.customer_device_recovery set status='resolved',resolved_at=now(),verification_note=trim(p_verification_note) where id=req.id;
 elsif p_action='reject' then
  update private.customer_device_recovery set status='rejected',resolved_at=now() where id=req.id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return jsonb_build_object('ok',true);
end $$;
revoke all on function public.admin_customer_device_recovery(text,text,uuid,text) from public,anon,authenticated;
grant execute on function public.admin_customer_device_recovery(text,text,uuid,text) to service_role;


create or replace function public.admin_customer_preorder_contacts(p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 select coalesce(jsonb_object_agg(x.key,x.instagram_handle),'{}') into result from (
  select 'native:'||id::text key,instagram_handle from public.preorders where instagram_handle<>''
  union all select 'web:'||id::text,instagram_handle from public.web_preorder_requests where instagram_handle<>''
 ) x; return result;
end $$;
revoke all on function public.admin_customer_preorder_contacts(text) from public,anon,authenticated;
grant execute on function public.admin_customer_preorder_contacts(text) to service_role;
