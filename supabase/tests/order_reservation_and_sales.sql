-- Run as database owner; all test data and stock changes are rolled back.
begin;
do $test$
declare
  b public.books%rowtype;
  v_id uuid;
  v_source text;
  v_receipt text;
  v_before integer;
  v_sales bigint;
  v_report jsonb;
begin
  select * into b from public.books where is_active and stock >= 3 and price > 0 order by id limit 1 for update;
  if b.id is null then raise exception 'No stock for rollback test'; end if;
  select name into v_receipt from storage.objects where bucket_id='payment-receipts' and name like 'receipts/%' limit 1;
  foreach v_source in array array['telegram','app'] loop
    select stock into v_before from public.books where id=b.id;
    v_report := private.finance_report('all');
    select count(*) into v_sales from public.sales_log;
    insert into public.orders(customer_name,phone,address,source,delivery_type,items,subtotal,total,delivery_fee,payment_proof_path)
      values('Rollback test','00000000','Rollback test address',v_source,'택배',
        jsonb_build_array(jsonb_build_object('book_id',b.id,'title',b.title,'quantity',1,'unit_price',b.price)),
        b.price,b.price+4000,4000,case when v_source='app' then v_receipt else '' end)
      returning id into v_id;
    if v_source='telegram' then perform public._order_set_status_core(v_id,'new'); end if;
    if (select stock from public.books where id=b.id) <> v_before-1 then raise exception '%: submit did not reserve',v_source; end if;
    if (select count(*) from public.sales_log) <> v_sales then raise exception '%: pending counted as sold',v_source; end if;
    perform public._order_set_status_core(v_id,'accepted');
    perform public._order_set_status_core(v_id,'accepted');
    if (select stock from public.books where id=b.id) <> v_before-1 then raise exception '%: accept double deducted',v_source; end if;
    if (select count(*) from public.sales_log where order_id=v_id) <> 1 then raise exception '%: missing or duplicate sale',v_source; end if;
    if (private.finance_report('all')->>'sold_books')::bigint <> (v_report->>'sold_books')::bigint+1 then raise exception '%: finance sale missing',v_source; end if;
    if (private.finance_report('all')->>'delivery_revenue')::bigint <> (v_report->>'delivery_revenue')::bigint+4000 then raise exception '%: finance postage missing',v_source; end if;
    perform public._order_set_status_core(v_id,'cancelled');
    perform public._order_set_status_core(v_id,'cancelled');
    if (select stock from public.books where id=b.id) <> v_before then raise exception '%: cancellation not restored exactly once',v_source; end if;
    if exists(select 1 from public.sales_log where order_id=v_id) then raise exception '%: cancelled still sold',v_source; end if;
  end loop;
end;
$test$;
rollback;
