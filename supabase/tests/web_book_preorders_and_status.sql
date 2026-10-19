-- Integration fixture: all data, auth-stub DDL and queued HTTP requests roll back together.
-- No bank transfer or real push is sent. The real admin secret is never read.
do $test$
declare
 bid uuid; rid uuid:='fd7e0001-0000-4000-8000-000000000001';
 rid2 uuid:='fd7e0002-0000-4000-8000-000000000002';
 proof text; proof2 text; c jsonb; payload jsonb; result jsonb; event_id uuid; claim jsonb;
 auth_hash text:=md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure));
 before_count integer:=(select count(*) from public.web_preorder_requests);
 before_orders integer:=(select count(*) from public.orders);
 rejected boolean;
begin
 begin
  -- Only this transaction sees this test credential. PZ001 rolls the function back as well.
  execute $ddl$create or replace function public._admin_secret_ok(p_secret text) returns boolean
   language sql security definer set search_path='' as 'select $1 = ''preorder-fixture-only-20261020''';$ddl$;
  select id into bid from public.books where is_active and stock=0 limit 1;
  if bid is null then raise exception 'Need an existing sold-out book fixture'; end if;
  update public.books set preorder_enabled=true,preorder_arrival_note='Fixture ETA',
    preorder_deposit_min=5000,preorder_deposit_max=10000 where id=bid;
  c:=public.web_preorder_book_config(bid);
  assert c->>'arrival_note'='Fixture ETA','Book ETA missing';
  proof:=rid::text||'/proof-'||repeat('d',64)||'.jpg';
  proof2:=rid2::text||'/proof-'||repeat('e',64)||'.jpg';
  insert into storage.objects(bucket_id,name) values('web-preorder-assets',proof),('web-preorder-assets',proof2);
  payload:=jsonb_build_object('id',rid,'book_id',bid,'customer_name','Fixture','phone','01000000000',
   'quantity',2,'deposit_amount',10000,'payment_proof_path',proof,'terms_token',c->>'terms_token');
  rejected:=false;
  begin perform public.web_preorder_submit(payload||'{"terms_token":"stale"}'::jsonb);
  exception when others then rejected:=true; end;
  assert rejected,'Stale terms accepted';
  rejected:=false;
  begin perform public.web_preorder_submit(payload||'{"deposit_amount":9999}'::jsonb);
  exception when others then rejected:=true; end;
  assert rejected,'Tampered advance accepted';
  result:=public.web_preorder_submit(payload);
  assert result->>'status'='waiting','Submission missing';
  assert (select count(*)=2 from private.web_preorder_events where preorder_id=rid),'Customer/admin outbox missing';
  assert (select count(*)=1 from public.customer_push_messages where id in(select id from private.web_preorder_events where preorder_id=rid)),'Initial inbox missing';
  result:=public.web_preorder_submit(payload);
  assert (result->>'duplicate')::boolean,'Retry not idempotent';
  assert (select count(*)=2 from private.web_preorder_events where preorder_id=rid),'Duplicate delivery created';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('invalid','status',jsonb_build_object('id',rid,'status','accepted','version',1));
  exception when others then rejected:=true; end;
  assert rejected,'Unauthenticated status update';
  result:=public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','accepted','version',1));
  assert result->>'status'='accepted' and (result->>'version')::integer=2,'Accept failed';
  result:=public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','accepted','version',1));
  assert (result->>'duplicate')::boolean,'Status retry duplicated';
  assert (select count(*)=2 from public.customer_push_messages where id in(select id from private.web_preorder_events where preorder_id=rid)),'Accepted message missing/duplicated';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','cancelled','version',1,'note','fixture reason'));
  exception when others then rejected:=true; end;
  assert rejected,'Stale admin overwrote status';
  result:=public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','arrived','version',2));
  assert result->>'status'='arrived','Arrived failed';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','cancelled','version',3));
  exception when others then rejected:=true; end;
  assert rejected,'Cancellation without reason accepted';
  result:=public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','cancelled','version',3,'note','Fixture cancellation'));
  assert result->>'status'='cancelled','Cancellation failed';
  result:=public.admin_web_preorder_manage('preorder-fixture-only-20261020','status',jsonb_build_object('id',rid,'status','waiting','version',4,'note','Fixture reopening'));
  assert result->>'status'='waiting','Reopen failed';
  assert (select count(*)=5 from public.customer_push_messages where id in(select id from private.web_preorder_events where preorder_id=rid)),'Lifecycle inbox incomplete';
  assert (select arrival_note='Fixture ETA' and deposit_amount=10000 from public.web_preorder_requests where id=rid),'Historical terms changed';
  rejected:=false;
  begin perform public.web_preorder_submit(payload||jsonb_build_object('id',rid2,'payment_proof_path',rid2::text||'/proof-'||repeat('d',64)||'.jpg'));
  exception when others then rejected:=true; end;
  assert rejected,'Receipt reuse not rejected';
  update public.books set preorder_enabled=false where id=bid;
  c:=public.web_preorder_book_config(bid);
  rejected:=false;
  begin perform public.web_preorder_submit(payload||jsonb_build_object('id',rid2,'payment_proof_path',proof2,'terms_token',c->>'terms_token'));
  exception when others then rejected:=true; end;
  assert rejected,'Closed book accepts payments';
  -- Notification claim/delivery retry uses the internal secret only inside Postgres.
  select id into event_id from private.web_preorder_events where preorder_id=rid and audience='customer' order by version limit 1;
  rejected:=false;
  begin perform public.web_preorder_delivery('invalid',event_id); exception when others then rejected:=true; end;
  assert rejected,'Delivery leaked to unauthenticated caller';
  insert into public.push_subscriptions(endpoint,p256dh,auth,user_agent,phone) values
   ('https://preorder-fixture.invalid/a','fake','fake','fixture','01000000000'),
   ('https://preorder-fixture.invalid/b','fake','fake','fixture','01000000000');
  claim:=public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id);
  assert claim->>'title'='Oldindan buyurtma yuborildi','Noncanonical notification';
  result:=public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id);
  assert (result->>'skip')::boolean,'Concurrent delivery not skipped';
  assert jsonb_array_length(claim->'subscriptions')=2,'Recipient targeting failed';
  perform public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id,
   jsonb_build_object('claim_token',claim->>'claim_token','failed',1,'recipients',2,
    'delivered_keys',jsonb_build_array(md5('https://preorder-fixture.invalid/a'))));
  update private.web_preorder_events set claim_until=now()-interval '1 second' where id=event_id;
  claim:=public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id);
  assert jsonb_array_length(claim->'subscriptions')=1 and claim->'subscriptions'->0->>'endpoint'='https://preorder-fixture.invalid/b','Successful recipient was retried';
  perform public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id,
   jsonb_build_object('claim_token',claim->>'claim_token','failed',0,'recipients',1,
    'delivered_keys',jsonb_build_array(md5('https://preorder-fixture.invalid/b'))));
  assert (select delivery_state='sent' and cardinality(delivered_keys)=2 from private.web_preorder_events where id=event_id),'Retry delivery incomplete';
  update public.push_subscriptions set phone='01000000001' where endpoint like 'https://preorder-fixture.invalid/%';
  select id into event_id from private.web_preorder_events where preorder_id=rid and audience='customer' and version=2;
  claim:=public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id);
  assert jsonb_array_length(claim->'subscriptions')=0,'No-permission fixture not isolated';
  perform public.web_preorder_delivery((select event_secret from private.push_event_config where id),event_id,
   jsonb_build_object('claim_token',claim->>'claim_token','failed',0,'recipients',0,'delivered_keys','[]'::jsonb));
  assert (select delivery_state='no_subscribers' from private.web_preorder_events where id=event_id),'No-permission fallback failed';
  assert not has_table_privilege('anon','public.web_preorder_requests','select'),'Requests exposed';
  assert not has_function_privilege('anon','public.web_preorder_delivery(text,uuid,jsonb)','execute'),'Worker exposed';
  raise sqlstate 'PZ001' using message='fixture rollback';
 exception when sqlstate 'PZ001' then null;
 end;
 assert md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure))=auth_hash,'Auth fixture not restored';
 assert (select count(*) from public.web_preorder_requests)=before_count,'Fixture request persisted';
 assert (select count(*) from public.orders)=before_orders,'Existing orders changed';
end;
$test$;
select 'PASS: linked terms, advance, idempotency, accept/arrive/cancel/reopen, stale actions, inbox, private delivery, no-permission fallback; fixtures rolled back' as result;
