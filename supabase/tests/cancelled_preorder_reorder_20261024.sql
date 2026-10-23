-- Transactional regression test. Run on a test DB or inside SQL Editor.
-- This leaves ZERO new preorder rows, notices or stock changes after ROLLBACK.
begin;
do $test$
declare
  selected_book uuid;
  deposit integer;
  test_install text:='mb-regression-cancelled-20261024';
  first_result jsonb;
  retry_result jsonb;
  replacement jsonb;
  first_id bigint;
  second_id bigint;
  blocked boolean:=false;
begin
  select id,preorder_deposit_min into selected_book,deposit
    from public.books where is_active=true and preorder_enabled=true
    order by id limit 1;
  if selected_book is null then
    raise notice 'SKIP: No preorder-enabled book in this database';
    return;
  end if;
  first_result:=public.customer_preorder_submit(
    test_install,selected_book,'Test Customer','01000000000',1,deposit,
    'test:receipt-first','Rollback-only test');
  first_id:=(first_result->>'id')::bigint;
  if first_result->>'duplicate' <> 'false' then
    raise exception 'First request must create a new waiting preorder';
  end if;
  retry_result:=public.customer_preorder_submit(
    test_install,selected_book,'Test Customer','01000000000',1,deposit,
    'test:receipt-first','Rollback-only test');
  if (retry_result->>'id')::bigint<>first_id
     or retry_result->>'duplicate'<>'true' then
    raise exception 'Retry must be idempotent and retain the same ID';
  end if;
  begin
    perform public.customer_preorder_submit(
      test_install,selected_book,'Test Customer','01000000000',1,deposit,
      'test:different-active-receipt','Rollback-only test');
  exception when others then
    blocked:=position('faol' in SQLERRM)>0;
  end;
  if not blocked then raise exception 'Active duplicate must be blocked'; end if;
  update public.preorders set status='cancelled' where id=first_id;
  replacement:=public.customer_preorder_submit(
    test_install,selected_book,'Test Customer','01000000000',1,deposit,
    'test:new-receipt-after-cancel','Rollback-only test');
  second_id:=(replacement->>'id')::bigint;
  if second_id=first_id or replacement->>'duplicate'<>'false' then
    raise exception 'Cancelled preorder incorrectly prevented a new booking';
  end if;
  if not exists(select 1 from public.preorders
    where id=first_id and status='cancelled' and deposit_amount=deposit)
     or not exists(select 1 from public.preorders
    where id=second_id and status='waiting' and deposit_amount=deposit) then
    raise exception 'Preorder status or deposit changed incorrectly';
  end if;
  raise notice 'PASS: active protected, retries safe, cancelled preorder reordered';
end;
$test$;
rollback;
