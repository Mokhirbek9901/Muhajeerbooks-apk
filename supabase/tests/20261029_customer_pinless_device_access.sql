-- Synthetic fixtures only. The nested transaction always rolls back, even on
-- success, so orders, advances, stock and notification queues never persist.
do $pinless_test$
declare
 a text:='device:'||encode(extensions.gen_random_bytes(32),'hex');
 b text:='device:'||encode(extensions.gen_random_bytes(32),'hex');
 c text:='device:'||encode(extensions.gen_random_bytes(32),'hex');
 d private.customer_device_profiles;
 bid uuid:=gen_random_uuid(); pbid uuid:=gen_random_uuid(); oid uuid:=gen_random_uuid();
 receipt text:='receipts/pinless-test/'||gen_random_uuid()::text||'.jpg';
 receipt2 text:='receipts/pinless-test/'||gen_random_uuid()::text||'.jpg';
 install text:='pinless-fixture-'||gen_random_uuid()::text;
 phone text:='01000000001'; q jsonb; o jsonb; result jsonb; pid text; request_id uuid;
 before_orders bigint; before_preorders bigint; before_stock bigint; before_devices bigint;
 rid uuid:=gen_random_uuid(); wrid uuid:=gen_random_uuid(); payload jsonb; proof text; bookpath text; before_auth text; apns_a text:=encode(extensions.gen_random_bytes(32),'hex'); apns_b text:=encode(extensions.gen_random_bytes(32),'hex');
 err text; token text:=encode(extensions.gen_random_bytes(32),'hex');
begin
 before_auth:=md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure));
 select count(*) into before_orders from public.orders;
 select count(*) into before_preorders from public.preorders;
 select coalesce(sum(stock),0) into before_stock from public.books;
 select count(*) into before_devices from private.customer_device_profiles;
 begin
  perform public.customer_device_bootstrap(substr(a,8),install,'Fixture buyer',phone,'');
  -- A second device with the SAME name, phone and installation identifier must
  -- still have no authority over A's history. Identifiers are not secrets.
  perform public.customer_device_bootstrap(substr(b,8),install,'Fixture buyer',phone,'');
  d:=private.customer_device(a);
  if d.legacy_scope then raise exception 'Contact bootstrap gained old history'; end if;
  insert into public.books(id,title,price,cost_price,stock) values(bid,'PINless fixture',17000,8000,8);
  insert into public.books(id,title,price,cost_price,stock,preorder_enabled,preorder_deposit_min,preorder_deposit_max,preorder_arrival_note)
   values(pbid,'PINless preorder fixture',17000,8000,8,true,5000,10000,'Fixture arrival');
  insert into storage.objects(bucket_id,name) values('payment-receipts',receipt),('payment-receipts',receipt2);
  perform public.customer_device_dispatch(a,'customer_release_receipt',jsonb_build_object('p_path',receipt));
  perform public.customer_device_dispatch(a,'customer_release_receipt',jsonb_build_object('p_path',receipt2));
  begin
   perform public.customer_device_dispatch(b,'customer_release_receipt',jsonb_build_object('p_path',receipt));
   raise exception 'TEST FAILED: second device claimed receipt';
  exception when others then if sqlerrm not like '%Chek boshqa qurilmaga%' then raise; end if; end;
  o:=jsonb_build_object('id',oid,'customer_name','Fixture buyer','phone',phone,'address','Fixture test address 123',
   'delivery_type','택배','instagram_handle','','order_note','','subtotal',1,'delivery_fee',0,'total',1,'items',jsonb_build_array(jsonb_build_object('book_id',bid,'quantity',1,'unit_price',1)));
  q:=public.customer_device_dispatch(a,'customer_release_quote',jsonb_build_object('p_order',o));
  if (q->>'total')::integer<>21000 then raise exception 'Server trusted a caller price: %',q; end if;
  begin
   perform public.customer_device_dispatch(b,'customer_release_order',jsonb_build_object('p_quote_id',q->>'quote_id','p_order',o||jsonb_build_object('payment_proof_path',receipt)));
   raise exception 'TEST FAILED: second device used quote';
  exception when others then if sqlerrm not like '%Hisob yoki chek qurilmangizga%' then raise; end if; end;
  result:=public.customer_device_dispatch(a,'customer_release_order',jsonb_build_object('p_quote_id',q->>'quote_id','p_order',o||jsonb_build_object('payment_proof_path',receipt)));
  if result->>'id'<>oid::text then raise exception 'Order was not created'; end if;
  perform public.customer_device_dispatch(a,'customer_release_order',jsonb_build_object('p_quote_id',q->>'quote_id','p_order',o||jsonb_build_object('payment_proof_path',receipt)));
  if (select stock from public.books where id=bid)<>7 then raise exception 'Retry deducted stock twice'; end if;
  if jsonb_array_length(public.customer_device_dispatch(a,'customer_release_my_orders','{}'))<>1 then raise exception 'Owner lost order'; end if;
  perform public.customer_device_dispatch(b,'customer_release_link_orders',jsonb_build_object('p_ids',jsonb_build_array(oid)));
  if public.customer_device_dispatch(b,'customer_release_my_orders','{}')<>'[]' then raise exception 'Phone plus order ID exposed private order'; end if;
  begin
   perform public.customer_device_dispatch(b,'customer_release_order',jsonb_build_object('p_quote_id',q->>'quote_id','p_order',o||jsonb_build_object('payment_proof_path',receipt)));
   raise exception 'TEST FAILED: same-phone duplicate disclosed order';
  exception when others then if sqlerrm not like '%Buyurtma boshqa qurilmaga%' then raise; end if; end;
  insert into private.push_event_config(id,event_secret) values(true,'pinless-fixture-event-secret') on conflict(id) do update set event_secret=excluded.event_secret;
  perform public.customer_device_dispatch(a,'customer_release_apns',jsonb_build_object('p_token',apns_a,'p_install_id',install,'p_enabled',true));
  perform public.customer_device_dispatch(b,'customer_release_apns',jsonb_build_object('p_token',apns_b,'p_install_id',install,'p_enabled',true));
  if (select count(*) from public.event_customer_device_apns('pinless-fixture-event-secret',phone,oid))<>1 or not exists(select 1 from public.event_customer_device_apns('pinless-fixture-event-secret',phone,oid) x where x.token=apns_a) then raise exception 'Same-phone device received another owner notification'; end if;
  perform public.customer_device_dispatch(a,'customer_release_push_subscribe',jsonb_build_object('p_endpoint','https://push.example.test/a-'||oid,'p_p256dh',repeat('a',87),'p_auth',repeat('b',22)));
  perform public.customer_device_dispatch(b,'customer_release_push_subscribe',jsonb_build_object('p_endpoint','https://push.example.test/b-'||oid,'p_p256dh',repeat('c',87),'p_auth',repeat('d',22)));
  if (select count(*) from public.event_customer_device_webpush('pinless-fixture-event-secret',phone,oid))<>1 then raise exception 'WebPush recipients leaked across same-phone devices'; end if;
  begin
   perform public.customer_device_dispatch(a,'admin_verify','{}');
   raise exception 'TEST FAILED: arbitrary operation reached privileged RPC';
  exception when others then if sqlerrm not like '%Amalga ruxsat yo‘q%' then raise; end if; end;
  begin
   perform public.customer_device_dispatch(a,'customer_release_quote',jsonb_build_object('p_admin_token',gen_random_uuid(),'p_order',o));
   raise exception 'TEST FAILED: customer used professional path';
  exception when others then if sqlerrm not like '%Admin kirishini alohida%' then raise; end if; end;
  begin
   perform public.customer_device_dispatch(a,'customer_preorder_submit',jsonb_build_object('p_book_id',pbid,'p_quantity',1,'p_deposit_amount',5000,'p_payment_proof_path',receipt2));
   raise exception 'TEST FAILED: missing Instagram accepted';
  exception when others then if sqlerrm not like '%Instagram username kiriting%' then raise; end if; end;
  result:=public.customer_device_dispatch(a,'customer_preorder_submit',jsonb_build_object('p_book_id',pbid,'p_quantity',1,'p_deposit_amount',5000,'p_payment_proof_path',receipt2,'p_instagram_handle','@fixture_reader'));
  pid:=result->>'id';
  if (select instagram_handle from public.preorders where id=pid::bigint)<>'fixture_reader' then raise exception 'Instagram contact was not saved'; end if;
  update public.preorders set status='arrived' where id=pid::bigint;
  perform private.release_preorder_ensure('native',pid);
  perform private.release_preorder_recalculate('native',pid);
  result:=public.customer_device_dispatch(a,'customer_release_preorders','{}');
  if jsonb_array_length(result)<>1 or (result->0->>'deposit_credit')::integer<>5000 or (result->0->>'amount_due')::integer<>16000 then raise exception 'Advance/balance changed or lost: %',result; end if;
  update private.release_preorder_invoices set balance_paid=3000 where source='native' and reference=pid;
  perform private.release_preorder_recalculate('native',pid);
  result:=public.customer_device_dispatch(a,'customer_release_preorders','{}');
  if (result->0->>'amount_due')::integer<>13000 then raise exception 'Remaining payment was not subtracted: %',result; end if;
  if public.customer_device_dispatch(b,'customer_release_preorders','{}')<>'[]' then raise exception 'Typed contact/install ID exposed preorder'; end if;
  begin
   perform public.customer_device_dispatch(b,'customer_release_preorder',jsonb_build_object('p_source','native','p_id',pid,'p_action','detail'));
   raise exception 'TEST FAILED: another device opened preorder by ID';
  exception when others then if sqlerrm not like '%Bu buyurtma qurilmangizga%' then raise; end if; end;
  result:=public.customer_device_dispatch(b,'customer_device_recovery_request',jsonb_build_object('p_note','Fixture request: buyer must be independently verified'));
  request_id:=(result->>'request_id')::uuid;
  if request_id is null then raise exception 'Recovery not requested'; end if;
  begin
   perform public.admin_customer_device_recovery('invalid-fixture-secret','approve',request_id,'Independent verification fixture');
   raise exception 'TEST FAILED: customer approved recovery';
  exception when others then if sqlerrm not like '%Ruxsat yo‘q%' then raise; end if; end;
  -- Single and multi-book advance requests retain Instagram with their proof.
  insert into public.web_preorder_settings(id,enabled,arrival_note,deposit_amount,revision)
   values(true,true,'Fixture arrival',5000,777)
   on conflict(id) do update set enabled=true,arrival_note='Fixture arrival',deposit_amount=5000,revision=777;
  proof:=rid::text||'/proof-'||repeat('a',64)||'.jpg';
  bookpath:=rid::text||'/book-'||repeat('b',64)||'.jpg';
  insert into storage.objects(bucket_id,name) values('web-preorder-assets',proof),('web-preorder-assets',bookpath);
  payload:=jsonb_build_object('id',rid,'install_id',install,'customer_name','Fixture buyer','phone',phone,
   'book_title','Fixture custom title','book_image_path',bookpath,'quantity',1,'payment_proof_path',proof,
   'deposit_amount',5000,'revision',777,'instagram_handle','@fixture_reader');
  result:=public.customer_device_dispatch(a,'web_preorder_submit',jsonb_build_object('p_request',payload));
  if result->>'id'<>rid::text or (select instagram_handle from public.web_preorder_requests where id=rid)<>'fixture_reader' then raise exception 'Single web request lost Instagram'; end if;
  perform public.customer_device_dispatch(a,'web_preorder_submit',jsonb_build_object('p_request',payload));
  begin
   perform public.customer_device_dispatch(b,'web_preorder_submit',jsonb_build_object('p_request',payload));
   raise exception 'TEST FAILED: other device replayed web request UUID';
  exception when others then if sqlerrm not like '%Buyurtma IDsi boshqa qurilmaga%' then raise; end if; end;
  proof:=wrid::text||'/proof-'||repeat('c',64)||'.jpg';
  bookpath:=wrid::text||'/book-'||repeat('d',64)||'.jpg';
  insert into storage.objects(bucket_id,name) values('web-preorder-assets',proof),('web-preorder-assets',bookpath);
  payload:=jsonb_build_object('id',wrid,'install_id',install,'customer_name','Fixture buyer','phone',phone,
   'items',jsonb_build_array(jsonb_build_object('book_title','Fixture multi title','book_image_path',bookpath,'quantity',2)),
   'payment_proof_path',proof,'deposit_amount',10000,'revision',777,'instagram_handle','fixture_reader');
  perform public.customer_device_dispatch(a,'web_preorder_submit_multi',jsonb_build_object('p_request',payload));
  if not exists(select 1 from public.web_preorder_requests where id=wrid and instagram_handle='fixture_reader' and deposit_amount=10000 and quantity=2) then raise exception 'Multi request lost advance/contact'; end if;
  if public.customer_device_dispatch(b,'customer_release_preorders','{}')<>'[]' then raise exception 'Web history leaked to same contact'; end if;

  -- The test authenticator exists only inside this rolled-back subtransaction.
  -- Real administrator authentication is restored and hash-checked below.
  execute $ddl$create or replace function public._admin_secret_ok(p_secret text) returns boolean
   language sql security definer set search_path='' as 'select $1 = ''pinless-fixture-admin-only''';$ddl$;
  perform public.admin_customer_device_recovery('pinless-fixture-admin-only','approve',request_id,'Verified fixture original order and receipt independently');
  if jsonb_array_length(public.customer_device_dispatch(b,'customer_release_my_orders','{}'))<>1 then raise exception 'Approved recovery did not restore order'; end if;
  result:=public.customer_device_dispatch(b,'customer_release_preorders','{}');
  if jsonb_array_length(result)<>3 then raise exception 'Approved recovery lost preorders: %',result; end if;
  if (select amount_due from private.release_preorder_invoices where source='native' and reference=pid)<>13000 then raise exception 'Recovery altered advances or balances'; end if;
  if not exists(select 1 from private.customer_device_recovery where id=request_id and status='resolved' and verification_note<>'') then raise exception 'Recovery was not audited'; end if;
  begin
   perform public.customer_device_dispatch(a,'customer_release_my_orders','{}');
   raise exception 'TEST FAILED: recovery did not revoke prior device';
  exception when others then if sqlerrm not like '%Qurilma kirishi tasdiqlanmadi%' then raise; end if; end;
  -- A real old session on this installation can migrate without entering PIN.
  insert into private.customer_pin_sessions(token_hash,phone_key,install_id,expires_at)
   values(encode(extensions.digest(token,'sha256'),'hex'),public._customer_phone_key(phone),install,now()+interval '10 minutes');
  insert into private.customer_pin_devices(phone_key,install_id) values(public._customer_phone_key(phone),install) on conflict do nothing;
  perform public.customer_device_bootstrap(substr(c,8),install||'-other','Fixture buyer',phone,token);
  if public.customer_device_dispatch(c,'customer_release_my_orders','{}')<>'[]' then raise exception 'Other installation reused legacy session'; end if;
  -- Logging out must revoke the opaque credential and leave financial rows intact.
  perform public.customer_device_dispatch(b,'customer_pin_logout','{}');
  begin
   perform public.customer_device_dispatch(b,'customer_release_my_orders','{}');
   raise exception 'TEST FAILED: logged-out credential still works';
  exception when others then if sqlerrm not like '%Qurilma kirishi tasdiqlanmadi%' then raise; end if; end;
  if not exists(select 1 from public.orders where id=oid) or not exists(select 1 from public.preorders where id=pid::bigint and deposit_amount=5000) then raise exception 'Logout removed financial data'; end if;
  if has_function_privilege('anon','public.customer_device_dispatch(text,text,jsonb)','execute') or has_function_privilege('authenticated','public.customer_device_bootstrap(text,text,text,text,text)','execute') then raise exception 'Direct privileged API exposed'; end if;
  raise sqlstate 'PZ001' using message='pinless fixture rollback';
 exception when sqlstate 'PZ001' then if sqlerrm<>'pinless fixture rollback' then raise; end if;
 end;
 if md5(pg_get_functiondef('public._admin_secret_ok(text)'::regprocedure))<>before_auth then raise exception 'Test authenticator was not rolled back'; end if;
 if (select count(*) from public.orders)<>before_orders or (select count(*) from public.preorders)<>before_preorders or (select coalesce(sum(stock),0) from public.books)<>before_stock or (select count(*) from private.customer_device_profiles)<>before_devices then raise exception 'Fixture cleanup changed live data'; end if;
end $pinless_test$;
select 'PINLESS_SECURITY_CHECKOUT_ADVANCE_INSTAGRAM_PASS' as result;
