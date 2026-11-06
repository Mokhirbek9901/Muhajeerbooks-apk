-- Preserve existing customer device ownership / capability guards.
-- Only display the actual secure preorder event title and body (customer-owned)
-- instead of a generic message in the mobile customer notification inbox.
CREATE OR REPLACE FUNCTION public.customer_device_dispatch(p_device_session text, p_action text, p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d private.customer_device_profiles:=private.customer_device(p_device_session); p jsonb:=coalesce(p_params,'{}');
 t text; th text; result jsonb; row jsonb; r record; oid uuid; qid uuid; v_path text; source text; reference text;
 added_device integer:=0; needs_session boolean:=false; compat_install text; instagram text; v_contact_platform text := 'instagram';
begin
 if jsonb_typeof(p)<>'object' or length(p::text)>100000 then raise exception 'So‘rov juda katta'; end if;
 if p_action in ('customer_preorder_submit','web_preorder_submit','web_preorder_submit_multi') then
  instagram:=regexp_replace(trim(coalesce(case when p_action='customer_preorder_submit' then p->>'p_instagram_handle' else p->'p_request'->>'instagram_handle' end,'')),'^@','');
  v_contact_platform:=lower(trim(coalesce(
     case when p_action='customer_preorder_submit'
          then p->>'p_contact_platform'
          else p->'p_request'->>'contact_platform' end,'instagram')));
  if v_contact_platform not in ('instagram','telegram') then
    raise exception 'Instagram yoki Telegram tanlang';
  end if;
  if (v_contact_platform='instagram' and instagram !~ '^[A-Za-z0-9._]{1,30}$') or
     (v_contact_platform='telegram' and instagram !~ '^[A-Za-z0-9_]{5,32}$') then
    raise exception 'Tanlangan tarmoqning username manzilini tekshiring: @username';
  end if;
  p:=p-'p_instagram_handle'-'p_contact_platform';
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
  update private.customer_apns_devices set opted_in=false where token in(select x.token from private.customer_device_apns x where x.device_id=d.id);
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
 if p_action='customer_release_apns' then
  if p->>'p_install_id' is distinct from d.install_id or coalesce(p->>'p_token','') !~ '^[0-9a-fA-F]{64,200}$' then raise exception 'Qurilma push ma’lumoti noto‘g‘ri'; end if;
  if coalesce((p->>'p_enabled')::boolean,true) then
   update private.customer_apns_devices set opted_in=false where token in(select x.token from private.customer_device_apns x where x.device_id=d.id and x.token<>lower(p->>'p_token'));
   insert into private.customer_apns_devices(token,phone_digits,install_id,opted_in,last_seen_at)
    values(lower(p->>'p_token'),regexp_replace(d.display_phone,'[^0-9]','','g'),d.install_id,true,now())
    on conflict(token) do update set phone_digits=excluded.phone_digits,install_id=excluded.install_id,opted_in=true,last_seen_at=now();
   insert into private.customer_device_apns values(lower(p->>'p_token'),d.id) on conflict(token) do update set device_id=excluded.device_id;
  else
   update private.customer_apns_devices set opted_in=false where token=lower(p->>'p_token') and token in(select x.token from private.customer_device_apns x where x.device_id=d.id);
  end if;
  return 'true';
 end if;
 if p_action='customer_release_reviews' then
  select coalesce(jsonb_agg(jsonb_build_object('id',rv.id,'book_id',rv.book_id,'reviewer_name',rv.reviewer_name,
   'rating',rv.rating,'comment',rv.comment,'created_at',rv.created_at) order by rv.created_at desc),'[]') into result
   from public.book_reviews rv join public.orders o on o.id=rv.order_id where rv.book_id=(p->>'p_book_id')::uuid and rv.is_approved
    and not exists(select 1 from private.release_review_blocks b where b.phone_key='device:'||d.id::text and b.author_key=public._customer_phone_key(o.phone));
  return result;
 end if;
 if p_action='customer_release_review_action' then
  select public._customer_phone_key(o.phone) into v_path from public.book_reviews rv join public.orders o on o.id=rv.order_id where rv.id=(p->>'p_review_id')::uuid;
  if v_path is null then raise exception 'Sharh topilmadi'; end if;
  if p->>'p_action'='report' then
   if length(trim(coalesce(p->>'p_reason',''))) not between 3 and 500 then raise exception 'Shikoyat sababini kiriting'; end if;
   insert into private.release_review_reports(review_id,phone_key,reason) values((p->>'p_review_id')::uuid,'device:'||d.id::text,trim(p->>'p_reason'))
    on conflict(review_id,phone_key) do update set reason=excluded.reason,status='pending';
  elsif p->>'p_action'='block' then insert into private.release_review_blocks values('device:'||d.id::text,v_path,now()) on conflict do nothing;
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
   union all select 'web:'||e.id::text,'web',e.preorder_id::text,e.status,coalesce(nullif(e.title,''),'Oldindan zakas'),coalesce(nullif(e.body,''),'Oldindan zakaslarim bo‘limini tekshiring.'),e.created_at
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
   v_path:=case when p_action='customer_release_preorder' then p->'p_payload'->>'path' else p->>'p_path' end;
   if not exists(select 1 from private.customer_device_receipts x where x.path=v_path and x.device_id=d.id) then raise exception 'Chek qurilmangizga tegishli emas'; end if;
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
  oid:=(p->'p_order'->>'id')::uuid; qid:=(p->>'p_quote_id')::uuid; v_path:=p->'p_order'->>'payment_proof_path';
  perform pg_advisory_xact_lock(hashtextextended('device-order:'||oid::text,29));
  if exists(select 1 from public.orders where id=oid) and not private.customer_device_owns_order(d,oid) then raise exception 'Buyurtma boshqa qurilmaga tegishli'; end if;
  if not exists(select 1 from private.customer_device_quotes x where x.quote_id=qid and x.device_id=d.id)
   or not exists(select 1 from private.customer_device_receipts x where x.path=v_path and x.device_id=d.id) then raise exception 'Hisob yoki chek qurilmangizga tegishli emas'; end if;
 end if;
 if p_action='customer_release_receipt' then
  v_path:=p->>'p_path';
  perform pg_advisory_xact_lock(hashtextextended('device-receipt:'||coalesce(v_path,''),29));
  if exists(select 1 from private.customer_device_receipts x where x.path=v_path and x.device_id<>d.id) then raise exception 'Chek boshqa qurilmaga tegishli'; end if;
 end if;
 -- Reuse validated price, stock, receipt and advance-ledger routines. The
 -- temporary session/device link exists only inside this transaction and is
 -- removed before returning. It is never sent to the application.
 select 'p_session'=any(proargnames) into needs_session from pg_catalog.pg_proc f join pg_catalog.pg_namespace n on n.oid=f.pronamespace
  where n.nspname='public' and f.proname=p_action;
 needs_session:=coalesce(needs_session,false) or p_action in ('customer_preorder_submit','web_preorder_submit','web_preorder_submit_multi');
 if needs_session then
  perform pg_advisory_xact_lock(hashtextextended('device-compat:'||d.phone_key||':'||d.install_id,29));
  t:=encode(extensions.gen_random_bytes(32),'hex'); th:=encode(extensions.digest(t,'sha256'),'hex');
  insert into private.customer_pin_sessions(token_hash,phone_key,install_id,expires_at) values(th,d.phone_key,d.install_id,now()+interval '1 minute');
  compat_install:=d.install_id;
  if source is not null then compat_install:=coalesce(nullif(private.release_preorder_context(source,reference)->>'install_id',''),d.install_id); end if;
  insert into private.customer_pin_devices(phone_key,install_id) values(d.phone_key,compat_install) on conflict do nothing;
  get diagnostics added_device=row_count;
  if p_action in ('web_preorder_submit','web_preorder_submit_multi') then p:=jsonb_set(p,'{p_request,session}',to_jsonb(t));
  elsif p_action<>'customer_preorder_submit' then p:=p||jsonb_build_object('p_session',t); end if;
 end if;
 p:=p-'p_proofs';
 result:=private.customer_device_call(p_action,p);
 if p_action='customer_release_quote' then
  insert into private.customer_device_quotes values((result->>'quote_id')::uuid,d.id);
 elsif p_action='customer_release_order' then
  insert into private.customer_device_orders values((result->>'id')::uuid,d.id) on conflict do nothing;
 elsif p_action='customer_release_apns' then
  insert into private.customer_device_apns values(lower(p->>'p_token'),d.id) on conflict(token) do update set device_id=excluded.device_id;
 elsif p_action='customer_preorder_submit' then
  insert into private.customer_device_preorders values('native',result->>'id',d.id) on conflict do nothing;
  update public.preorders set instagram_handle=instagram,contact_platform=v_contact_platform where id=(result->>'id')::bigint;
 elsif p_action in ('web_preorder_submit','web_preorder_submit_multi') then
  insert into private.customer_device_preorders values('web',result->>'id',d.id) on conflict do nothing;
  update public.web_preorder_requests set instagram_handle=instagram,contact_platform=v_contact_platform where id=(result->>'id')::uuid;
 elsif p_action='customer_release_receipt' then
  insert into private.customer_device_receipts values(v_path,d.id) on conflict do nothing;
 end if;
 if needs_session then
  -- The web subscription is bound separately to the durable device, never t.
  delete from private.customer_pin_sessions where token_hash=th;
  if added_device>0 then delete from private.customer_pin_devices where phone_key=d.phone_key and install_id=compat_install; end if;
 end if;
 return result;
end $function$;
