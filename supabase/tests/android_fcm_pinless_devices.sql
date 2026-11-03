-- Every fixture, receipt, stock reservation and push event is rolled back.
-- No provider call is made and no real customer order is used.
do $test$
declare
 a text:='device:'||encode(extensions.gen_random_bytes(32),'hex');
 b text:='device:'||encode(extensions.gen_random_bytes(32),'hex');
 ta text:='Case_A:'||encode(extensions.gen_random_bytes(32),'hex');
 tb text:='Case_B:'||encode(extensions.gen_random_bytes(32),'hex');
 tc text:='Case_C:'||encode(extensions.gen_random_bytes(32),'hex');
 ios_a text:=encode(extensions.gen_random_bytes(32),'hex');
 ios_b text:=encode(extensions.gen_random_bytes(32),'hex');
 ios_legacy text:=encode(extensions.gen_random_bytes(32),'hex');
 legacy_session text:=encode(extensions.gen_random_bytes(32),'hex');
 install text:='fcm-fixture-'||gen_random_uuid()::text;
 phone text:='01000000001'; event_key text:='fcm-test-'||gen_random_uuid()::text;
 bid uuid:=gen_random_uuid(); oid uuid:=gen_random_uuid();
 receipt text:='receipts/fcm-fixture/'||gen_random_uuid()::text||'.jpg';
 d private.customer_device_profiles; o jsonb; q jsonb;
 before_devices bigint; before_tokens bigint; before_orders bigint; before_apns bigint; config_hash text;
begin
 select count(*) into before_devices from private.customer_device_profiles;
 select count(*) into before_tokens from private.native_fcm_devices;
 select count(*) into before_orders from public.orders;
 select count(*) into before_apns from private.customer_apns_devices;
 select md5(event_secret) into config_hash from private.push_event_config where id;
 begin
  perform public.customer_device_bootstrap(substr(a,8),install,'FCM fixture',phone,'');
  perform public.customer_device_bootstrap(substr(b,8),install,'FCM fixture',phone,'');
  d:=private.customer_device(a);
  insert into public.books(id,title,price,cost_price,stock) values(bid,'FCM fixture',17000,8000,8);
  insert into storage.objects(bucket_id,name) values('payment-receipts',receipt);
  perform public.customer_device_dispatch(a,'customer_release_receipt',jsonb_build_object('p_path',receipt));
  o:=jsonb_build_object('id',oid,'customer_name','FCM fixture','phone',phone,
   'address','Fixture test address 123','delivery_type','택배','instagram_handle','','order_note','','items',
   jsonb_build_array(jsonb_build_object('book_id',bid,'quantity',1,'unit_price',1)));
  q:=public.customer_device_dispatch(a,'customer_release_quote',jsonb_build_object('p_order',o));
  perform public.customer_device_dispatch(a,'customer_release_order',jsonb_build_object(
   'p_quote_id',q->>'quote_id','p_order',o||jsonb_build_object('payment_proof_path',receipt)));
  insert into private.push_event_config(id,event_secret) values(true,event_key)
   on conflict(id) do update set event_secret=excluded.event_secret;
  perform public.customer_release_fcm(a,ta,install,true);
  perform public.customer_release_fcm(b,tb,install,true);
  perform public.customer_device_dispatch(a,'customer_release_apns',jsonb_build_object('p_token',ios_a,'p_install_id',install,'p_enabled',true));
  perform public.customer_device_dispatch(b,'customer_release_apns',jsonb_build_object('p_token',ios_b,'p_install_id',install,'p_enabled',true));
  if not exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_a)
   or exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_b)
   or exists(select 1 from public.event_customer_device_apns(event_key,phone,gen_random_uuid()))
   then raise exception 'APNs exact-order device ownership failed'; end if;
  insert into private.customer_pin_profiles(phone_key,display_phone,full_name,pin_hash)
   values(public._customer_phone_key(phone),phone,'APNs legacy fixture',extensions.crypt('1234',extensions.gen_salt('bf')));
  insert into private.customer_pin_devices(phone_key,install_id) values(public._customer_phone_key(phone),install||'-legacy');
  insert into private.customer_pin_sessions(token_hash,phone_key,install_id,expires_at)
   values(encode(extensions.digest(legacy_session,'sha256'),'hex'),public._customer_phone_key(phone),install||'-legacy',now()+interval '1 hour');
  insert into private.release_order_owners(order_id,phone_key) values(oid,public._customer_phone_key(phone))
   on conflict(order_id) do update set phone_key=excluded.phone_key;
  perform public.customer_register_native_apns(ios_legacy,phone,install||'-legacy');
  if exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_legacy)
   then raise exception 'Phone-only APNs token received private order'; end if;
  perform public.customer_release_apns(legacy_session,ios_legacy,install||'-legacy',true);
  if not exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_legacy)
   then raise exception 'Authenticated legacy APNs session lost compatibility'; end if;
  update private.customer_pin_sessions set expires_at=now()-interval '1 minute'
   where token_hash=encode(extensions.digest(legacy_session,'sha256'),'hex');
  if exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_legacy)
   then raise exception 'Expired legacy APNs session still received order'; end if;
  if (select count(*) from public.event_native_fcm_for_order(event_key,phone,oid))<>1
   or not exists(select 1 from public.event_native_fcm_for_order(event_key,phone,oid) x where x.token=ta)
   then raise exception 'Same-phone device received another owner notification'; end if;
  if exists(select 1 from public.event_native_fcm_for_phone(event_key,phone) x where x.token in(ta,tb))
   then raise exception 'PINless tokens reached legacy phone lookup'; end if;
  if exists(select 1 from public.event_native_fcm_for_order(event_key,'01000000002',oid))
   or exists(select 1 from public.event_native_fcm_for_order(event_key,phone,gen_random_uuid()))
   then raise exception 'Wrong phone or order accepted'; end if;
  begin
   perform public.customer_release_fcm(a,tc,install||'-other',true);
   raise exception 'TEST FAILED: foreign installation accepted';
  exception when others then if sqlerrm not like '%Qurilma kirishi tasdiqlanmadi%' then raise; end if; end;
  begin
   perform public.customer_release_fcm(phone,tc,install,true);
   raise exception 'TEST FAILED: phone authorized registration';
  exception when others then if sqlerrm not like '%Hisobingizga qayta kiring%' then raise; end if; end;
  perform public.customer_release_fcm(a,tc,install,true);
  if exists(select 1 from private.native_fcm_devices where token=ta and customer_opted_in)
   or not exists(select 1 from private.native_fcm_devices where token=tb and customer_opted_in)
   then raise exception 'Token rotation affected another device profile'; end if;
  perform public.customer_release_fcm(a,'',install,false);
  if exists(select 1 from public.event_native_fcm_for_order(event_key,phone,oid))
   then raise exception 'Disabled device still received push'; end if;
  perform public.customer_release_fcm(a,ta,install,true);
  perform public.customer_device_dispatch(a,'customer_pin_logout','{}');
  if exists(select 1 from public.event_customer_device_apns(event_key,phone,oid) x where x.token=ios_a)
   then raise exception 'Logged-out APNs profile still received order'; end if;
  if exists(select 1 from private.native_fcm_devices where token=ta and customer_opted_in)
   or exists(select 1 from public.event_native_fcm_for_order(event_key,phone,oid))
   then raise exception 'Logout did not revoke Android push'; end if;
  begin
   perform public.customer_release_fcm(a,ta,install,true);
   raise exception 'TEST FAILED: logged-out session re-registered';
  exception when others then if sqlerrm not like '%Qurilma kirishi tasdiqlanmadi%' then raise; end if; end;
  if has_function_privilege('anon','public.customer_release_fcm(text,text,text,boolean)','execute')
   or has_function_privilege('authenticated','public.event_native_fcm_for_order(text,text,uuid)','execute')
   then raise exception 'Direct privileged RPC exposed'; end if;
  begin
   perform public.event_native_fcm_for_order('wrong-secret',phone,oid);
   raise exception 'TEST FAILED: unauthenticated sender enumerated tokens';
  exception when others then if sqlerrm<>'Unauthorized push event' then raise; end if; end;
  raise sqlstate 'PZ001' using message='fcm fixture rollback';
 exception when sqlstate 'PZ001' then if sqlerrm<>'fcm fixture rollback' then raise; end if;
 end;
 if (select count(*) from private.customer_device_profiles)<>before_devices
  or (select count(*) from private.native_fcm_devices)<>before_tokens
  or (select count(*) from public.orders)<>before_orders
  or (select count(*) from private.customer_apns_devices)<>before_apns
  or (select md5(event_secret) from private.push_event_config where id) is distinct from config_hash
  then raise exception 'Fixtures were not fully rolled back'; end if;
end $test$;
select 'ANDROID_FCM_DEVICE_ISOLATION_ROTATION_LOGOUT_PASS' as result;
