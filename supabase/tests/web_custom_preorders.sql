-- Transactional fixtures: every fixture row is rolled back, including on failure.
do $test$
declare
  rid uuid := '00000000-0000-4000-8000-000000000001';
  rid2 uuid := '00000000-0000-4000-8000-000000000002';
  bookpath text := rid::text||'/book-'||repeat('a',64)||'.jpg';
  proofpath text := rid::text||'/proof-'||repeat('b',64)||'.jpg';
  payload jsonb;
  result jsonb;
begin
  begin
    insert into storage.objects(bucket_id,name,metadata) values
      ('web-preorder-assets',bookpath,'{}'),('web-preorder-assets',proofpath,'{}');
    payload := jsonb_build_object('id',rid,'customer_name','Test fixture',
      'phone','01000000000','book_title','Fixture book','quantity',1,
      'book_image_path',bookpath,'payment_proof_path',proofpath,
      'deposit_amount',5000,'revision',777);
    update public.web_preorder_settings set enabled=false,arrival_note='Test ETA',revision=777;
    begin
      perform public.web_preorder_submit(payload);
      raise exception 'TEST FAILED: closed reception accepted';
    exception when others then
      if sqlerrm not like 'Oldindan buyurtma qabuli yopiq.%' then raise; end if;
    end;
    update public.web_preorder_settings set enabled=true,deposit_amount=5000;
    begin
      perform public.web_preorder_submit(payload||'{"revision":776}');
      raise exception 'TEST FAILED: stale terms accepted';
    exception when others then
      if sqlerrm not like 'Sana yoki avans o‘zgargan.%' then raise; end if;
    end;
    begin
      perform public.web_preorder_submit(payload||'{"deposit_amount":1}');
      raise exception 'TEST FAILED: tampered deposit accepted';
    exception when others then
      if sqlerrm not like 'Sana yoki avans o‘zgargan.%' then raise; end if;
    end;
    begin
      perform public.web_preorder_submit(payload||'{"payment_proof_path":"invalid"}');
      raise exception 'TEST FAILED: missing proof accepted';
    exception when others then
      if sqlerrm <> 'Kitob rasmi va to‘lov chekini yuklang.' then raise; end if;
    end;
    result := public.web_preorder_submit(payload);
    if result->>'status' <> 'waiting' then raise exception 'TEST FAILED: wrong initial state'; end if;
    result := public.web_preorder_submit(payload);
    if (result->>'duplicate')::boolean is not true then raise exception 'TEST FAILED: retry not idempotent'; end if;
    if (select count(*) from public.web_preorder_requests where id=rid) <> 1 then
      raise exception 'TEST FAILED: retry created duplicate rows'; end if;
    update public.web_preorder_settings set arrival_note='Changed ETA',revision=778;
    if (select arrival_note from public.web_preorder_requests where id=rid) <> 'Test ETA' then
      raise exception 'TEST FAILED: historical arrival changed'; end if;
    begin
      perform public.web_preorder_submit(payload||'{"quantity":2}');
      raise exception 'TEST FAILED: changed retry payload accepted';
    exception when others then
      if sqlerrm <> 'Buyurtma identifikatori boshqa so‘rovga tegishli.' then raise; end if;
    end;
    begin
      perform public.admin_web_preorder_manage('invalid-fixture-secret','settings');
      raise exception 'TEST FAILED: invalid admin code accepted';
    exception when others then
      if sqlerrm <> 'Ruxsat yo‘q' then raise; end if;
    end;
    insert into storage.objects(bucket_id,name,metadata) values
      ('web-preorder-assets',rid2::text||'/book-'||repeat('a',64)||'.jpg','{}'),
      ('web-preorder-assets',rid2::text||'/proof-'||repeat('b',64)||'.jpg','{}');
    begin
      perform public.web_preorder_submit(payload||jsonb_build_object('id',rid2,'revision',778,
        'book_image_path',rid2::text||'/book-'||repeat('a',64)||'.jpg',
        'payment_proof_path',rid2::text||'/proof-'||repeat('b',64)||'.jpg'));
      raise exception 'TEST FAILED: reused payment receipt accepted';
    exception when others then
      if sqlerrm not like 'Bu chek bo‘yicha buyurtma avval qabul qilingan.%' then raise; end if;
    end;
    if has_function_privilege('anon','public.web_preorder_config()','execute') or
       has_function_privilege('anon','public.web_preorder_submit(jsonb)','execute') or
       has_table_privilege('anon','public.web_preorder_requests','select') or
       (select public from storage.buckets where id='web-preorder-assets') then
      raise exception 'TEST FAILED: private data exposed';
    end if;
    raise exception using errcode='PZ001',message='Rollback successful fixtures';
  exception when sqlstate 'PZ001' then null;
  end;
end;
$test$;
select 'PASS: closed, stale, deposit, images, retry, historical terms, admin auth, receipt reuse, private access; fixtures rolled back' verification;
