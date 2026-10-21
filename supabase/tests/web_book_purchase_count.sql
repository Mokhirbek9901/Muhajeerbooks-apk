-- Synthetic fixtures only; rollback also discards any transactional outbox rows.
begin;
do $test$
declare
  bid uuid := gen_random_uuid();
  duplicate_id uuid := gen_random_uuid();
  oid uuid;
  title text := 'Purchase-count o‘yin ' || bid;
  counts jsonb;
begin
  insert into public.books(id,title,author,category,price,stock,is_active)
    values(bid,title,'Test','Test',10000,4,true);
  insert into public.legacy_sales_history(title,sold_at,import_batch)
    values(replace(title,'‘',''''),now(),'rollback_purchase_count_test');
  insert into public.orders(customer_name,phone,address,source,delivery_type,items,subtotal,total,delivery_fee)
    values('Rollback test','','Rollback test','telegram','pickup',
      jsonb_build_array(jsonb_build_object('book_id',bid,'title',title,'quantity',2,'unit_price',10000)),20000,20000,0)
    returning id into oid;
  counts := public.web_book_purchase_count(bid);
  if counts <> '{"recorded_count":0,"historical_count":1}'::jsonb then
    raise exception 'Pending order counted or historic title matching failed: %',counts;
  end if;
  perform public._order_set_status_core(oid,'accepted');
  counts := public.web_book_purchase_count(bid);
  if counts <> '{"recorded_count":2,"historical_count":1}'::jsonb then
    raise exception 'Multi-copy confirmed sale counted incorrectly: %',counts;
  end if;
  perform public._order_set_status_core(oid,'accepted');
  if public.web_book_purchase_count(bid) <> counts then raise exception 'Repeated acceptance inflated count'; end if;
  perform public._order_set_status_core(oid,'cancelled');
  if public.web_book_purchase_count(bid) <> '{"recorded_count":0,"historical_count":1}'::jsonb then
    raise exception 'Cancelled sale still counted';
  end if;
  insert into public.books(id,title,author,category,price,stock,is_active)
    values(duplicate_id,title,'Other edition','Test',10000,0,true);
  if public.web_book_purchase_count(bid) <> '{"recorded_count":0,"historical_count":0}'::jsonb then
    raise exception 'Ambiguous historic title assigned to multiple books';
  end if;
  update public.books set is_active=false where id=duplicate_id;
  if public.web_book_purchase_count(duplicate_id) is not null then raise exception 'Inactive book exposed'; end if;
  if public.web_book_purchase_count(gen_random_uuid()) is not null then raise exception 'Unknown book returned fake zero'; end if;
  perform set_config('test.purchase_count_book_id',bid::text,true);
end;
$test$;
set local role anon;
select public.web_book_purchase_count(current_setting('test.purchase_count_book_id')::uuid) as anonymous_aggregate;
reset role;
rollback;
