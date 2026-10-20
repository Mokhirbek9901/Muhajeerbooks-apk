-- Run in a transaction. Fixtures and the test-only auth stub fully roll back.
do $test$
declare
 rid uuid:='fd8e0001-0000-4000-8000-000000000001'; rid2 uuid:='fd8e0002-0000-4000-8000-000000000002';
 items jsonb:='[]'; payload jsonb; r jsonb; c jsonb; path text; proof text; i integer; qty integer;
 auth_hash text:=md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure));
 before_requests integer:=(select count(*) from public.web_preorder_requests);
 before_orders integer:=(select count(*) from public.orders);
 before_inbox integer:=(select count(*) from public.customer_push_messages);
 rejected boolean;
begin
 begin
  execute $ddl$create or replace function public._admin_secret_ok(p_secret text) returns boolean
   language sql security definer set search_path='' as 'select $1 = ''multi-fixture-only-20261021''';$ddl$;
  update public.web_preorder_settings set enabled=true,arrival_note='Fixture multi ETA',deposit_amount=5000,revision=revision+1 where id;
  c:=public.web_preorder_config();
  for i in 1..4 loop
   path:=rid::text||'/book-'||repeat(i::text,64)||'.jpg'; qty:=case i when 2 then 2 when 4 then 20 else 1 end;
   insert into storage.objects(bucket_id,name) values('web-preorder-assets',path);
   items:=items||jsonb_build_array(jsonb_build_object('book_title','Fixture book '||i,'book_image_path',path,'quantity',qty));
  end loop;
  proof:=rid::text||'/proof-'||repeat('f',64)||'.jpg';
  insert into storage.objects(bucket_id,name) values('web-preorder-assets',proof);
  payload:=jsonb_build_object('id',rid,'items',items,'customer_name','Fixture','phone','01000000000',
   'payment_proof_path',proof,'deposit_amount',120000,'revision',c->'revision');
  rejected:=false;
  begin perform public.web_preorder_submit_multi(payload||'{"deposit_amount":10000}'::jsonb); exception when others then rejected:=true; end;
  assert rejected,'Tampered total accepted';
  rejected:=false;
  begin perform public.web_preorder_submit_multi(payload||'{"items":[]}'::jsonb); exception when others then rejected:=true; end;
  assert rejected,'Empty books accepted';
  rejected:=false;
  begin perform public.web_preorder_submit_multi(payload||'{"revision":-1}'::jsonb); exception when others then rejected:=true; end;
  assert rejected,'Stale terms accepted';
  rejected:=false;
  begin perform public.web_preorder_submit_multi(jsonb_set(payload,'{items,2,book_image_path}',to_jsonb(rid::text||'/book-'||repeat('e',64)||'.jpg')));
  exception when others then rejected:=true; end;
  assert rejected,'Missing image accepted';
  assert (select count(*)=0 from public.web_preorder_requests where id=rid),'Invalid bundle partially committed';
  r:=public.web_preorder_submit_multi(payload);
  assert r->>'status'='waiting','Multi request not created';
  assert (select quantity=24 and deposit_amount=120000 and jsonb_array_length(request_items)=4 from public.web_preorder_requests where id=rid),'Items or total lost';
  assert (select count(*)=2 from private.web_preorder_events where preorder_id=rid),'Initial customer/admin events missing';
  r:=public.web_preorder_submit_multi(payload);
  assert (r->>'duplicate')::boolean,'Retry not idempotent';
  assert (select count(*)=2 from private.web_preorder_events where preorder_id=rid),'Retry duplicated events';
  rejected:=false;
  begin perform public.web_preorder_submit_multi(jsonb_set(payload,'{items,0,book_title}','"Different book"'));
  exception when others then rejected:=true; end;
  assert rejected,'Existing ID accepted different contents';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','list','{"limit":200}');
  assert exists(select 1 from jsonb_array_elements(r) x where x->>'id'=rid::text and jsonb_array_length(x->'request_items')=4),'Admin lost item details';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('invalid','status',jsonb_build_object('id',rid,'status','accepted','version',1)); exception when others then rejected:=true; end;
  assert rejected,'Unauthenticated admin accepted request';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','arrived','version',1)); exception when others then rejected:=true; end;
  assert rejected,'Arrived before acceptance';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','accepted','version',1));
  assert r->>'status'='accepted' and (r->>'inbox_created')::boolean,'Accept/inbox failed';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','accepted','version',1));
  assert (r->>'duplicate')::boolean,'Duplicate accept not idempotent';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','cancelled','version',1,'note','Fixture reason')); exception when others then rejected:=true; end;
  assert rejected,'Stale admin overwrote request';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','arrived','version',2));
  assert r->>'status'='arrived','Arrived failed';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','accepted','version',3)); exception when others then rejected:=true; end;
  assert rejected,'Arrival regressed to accepted';
  rejected:=false;
  begin perform public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','cancelled','version',3)); exception when others then rejected:=true; end;
  assert rejected,'Cancellation accepted without reason';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','cancelled','version',3,'note','Fixture cancellation'));
  assert r->>'status'='cancelled','Cancel failed';
  r:=public.admin_web_preorder_manage('multi-fixture-only-20261021','status',jsonb_build_object('id',rid,'status','waiting','version',4,'note','Fixture reopen'));
  assert r->>'status'='waiting','Reopen failed';
  assert (select count(*)=5 from public.customer_push_messages where id in(select id from private.web_preorder_events where preorder_id=rid)),'Status notification history incomplete';
  -- Reusing the same receipt under a new ID is rejected even with valid owned images.
  items:=replace(items::text,rid::text,rid2::text)::jsonb;
  insert into storage.objects(bucket_id,name) select 'web-preorder-assets',x->>'book_image_path' from jsonb_array_elements(items) x;
  proof:=rid2::text||'/proof-'||repeat('f',64)||'.jpg';
  insert into storage.objects(bucket_id,name) values('web-preorder-assets',proof);
  rejected:=false;
  begin perform public.web_preorder_submit_multi(payload||jsonb_build_object('id',rid2,'items',items,'payment_proof_path',proof)); exception when others then rejected:=true; end;
  assert rejected,'Same receipt accepted twice';
  assert not has_function_privilege('anon','public.web_preorder_submit_multi(jsonb)','execute'),'Multi endpoint exposed';
  assert not has_table_privilege('anon','public.web_preorder_requests','select'),'Private requests exposed';
  raise sqlstate 'PZ001' using message='fixture rollback';
 exception when sqlstate 'PZ001' then null;
 end;
 assert md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure))=auth_hash,'Auth not restored';
 assert (select count(*) from public.web_preorder_requests)=before_requests,'Fixture persisted';
 assert (select count(*) from public.customer_push_messages)=before_inbox,'Fixture messages persisted';
 assert (select count(*) from public.orders)=before_orders,'Existing orders changed';
end;
$test$;
select 'PASS: multi-book atomic submission, totals, images, duplicate retry/receipt, admin lifecycle, conflict protection and durable notifications; all fixtures rolled back' as result;
