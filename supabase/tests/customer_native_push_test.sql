-- All fixtures and the event secret replacement roll back; no provider calls.
do $test$
declare
 d uuid:=gen_random_uuid(); r uuid:=gen_random_uuid();
 install text:='push-test-'||gen_random_uuid()::text;
 phone text:='01000000001'; secret text:=encode(extensions.gen_random_bytes(32),'hex');
 a text:=encode(extensions.gen_random_bytes(32),'hex');
 b text:=encode(extensions.gen_random_bytes(32),'hex');
 f text:='FixtureFcm:'||encode(extensions.gen_random_bytes(32),'hex');
 g text:='FixtureAdmin:'||encode(extensions.gen_random_bytes(32),'hex');
 before_ios bigint; before_android bigint; before_profiles bigint; before_secret text;
begin
 select count(*) into before_ios from private.customer_apns_devices;
 select count(*) into before_android from private.native_fcm_devices;
 select count(*) into before_profiles from private.customer_device_profiles;
 select md5(event_secret) into before_secret from private.push_event_config where id;
 begin
  insert into private.push_event_config(id,event_secret) values(true,secret)
   on conflict(id) do update set event_secret=excluded.event_secret;
  insert into private.customer_device_profiles(id,secret_hash,install_id,full_name,display_phone,phone_key,revoked_at)
   values(d,encode(extensions.gen_random_bytes(32),'hex'),install,'Push fixture',phone,public._customer_phone_key(phone),null),
   (r,encode(extensions.gen_random_bytes(32),'hex'),install||'-revoked','Push fixture',phone,public._customer_phone_key(phone),now());
  insert into private.customer_apns_devices(token,phone_digits,install_id,opted_in,last_seen_at)
   values(a,phone,install,true,now()),(b,phone,install||'-revoked',true,now());
  insert into private.customer_device_apns values(a,d),(b,r);
  insert into private.native_fcm_devices(token,phone_digits,install_id,customer_opted_in,device_profile_id,last_seen_at,admin_verified_at)
   values(f,phone,install,true,d,now(),null),(g,'',install||'-admin',false,null,now(),now());
  if not exists(select 1 from public.event_customer_apns_test_recipients(secret) x where x.token=a)
   or exists(select 1 from public.event_customer_apns_test_recipients(secret) x where x.token=b)
   then raise exception 'APNs active/revoked profile isolation failed'; end if;
  if not exists(select 1 from public.event_customer_fcm_test_recipients(secret) x where x.token=f)
   or exists(select 1 from public.event_customer_fcm_test_recipients(secret) x where x.token=g)
   then raise exception 'FCM customer/admin isolation failed'; end if;
  update private.customer_apns_devices set opted_in=false where token=a;
  update private.native_fcm_devices set customer_opted_in=false where token=f;
  if exists(select 1 from public.event_customer_apns_test_recipients(secret) x where x.token=a)
   or exists(select 1 from public.event_customer_fcm_test_recipients(secret) x where x.token=f)
   then raise exception 'Opt-out failed'; end if;
  begin
   perform public.event_customer_apns_test_recipients('wrong-secret');
   raise exception 'TEST FAILED: invalid event secret accepted';
  exception when others then if sqlerrm<>'Unauthorized push event' then raise; end if; end;
  begin
   perform public.event_customer_fcm_test_recipients('wrong-secret');
   raise exception 'TEST FAILED: invalid event secret accepted';
  exception when others then if sqlerrm<>'Unauthorized push event' then raise; end if; end;
  if has_function_privilege('anon','public.event_customer_apns_test_recipients(text)','execute')
   or has_function_privilege('authenticated','public.event_customer_fcm_test_recipients(text)','execute')
   then raise exception 'Customer test RPC exposed directly'; end if;
  raise sqlstate 'PZ001' using message='customer diagnostic fixture rollback';
 exception when sqlstate 'PZ001' then
  if sqlerrm<>'customer diagnostic fixture rollback' then raise; end if;
 end;
 if (select count(*) from private.customer_apns_devices)<>before_ios
  or (select count(*) from private.native_fcm_devices)<>before_android
  or (select count(*) from private.customer_device_profiles)<>before_profiles
  or (select md5(event_secret) from private.push_event_config where id) is distinct from before_secret
  then raise exception 'Fixtures were not rolled back'; end if;
end $test$;
select 'CUSTOMER_NATIVE_TEST_AUTH_OPT_IN_ISOLATION_PASS' as result;
