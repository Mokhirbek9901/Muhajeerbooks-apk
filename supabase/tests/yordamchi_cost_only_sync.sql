do $test$
declare
 b public.books%rowtype;
 after_book jsonb;
 original jsonb;
 sales_hash text;
 sales_after text;
 result jsonb;
begin
 if has_function_privilege('anon','public.yordamchi_update_book_costs(jsonb)','execute') or has_function_privilege('authenticated','public.yordamchi_update_book_costs(jsonb)','execute') then raise exception 'Client can write directly'; end if;
 if not has_function_privilege('service_role','public.yordamchi_update_book_costs(jsonb)','execute') then raise exception 'Service cannot write'; end if;
 -- Everything written by this inner transaction is rolled back before returning.
 begin
  select * into b from public.books order by id limit 1 for update;
  if not found then raise exception 'No fixture book'; end if;
  original:=to_jsonb(b)-array['cost_price','updated_at'];
  select md5(coalesce(string_agg(to_jsonb(s)::text,'' order by s.id),'')) into sales_hash from public.sales_log s;
  result:=public.yordamchi_update_book_costs(jsonb_build_array(jsonb_build_object('id',b.id,'cost_price',case when b.cost_price=5000 then 5001 else 5000 end,'expected_cost_price',b.cost_price)));
  select to_jsonb(x)-array['cost_price','updated_at'] into after_book from public.books x where x.id=b.id;
  if after_book is distinct from original then raise exception 'Other book fields changed'; end if;
  select md5(coalesce(string_agg(to_jsonb(s)::text,'' order by s.id),'')) into sales_after from public.sales_log s;
  if sales_after is distinct from sales_hash then raise exception 'Sales statistics changed'; end if;
  begin
   perform public.yordamchi_update_book_costs(jsonb_build_array(jsonb_build_object('id',b.id,'cost_price',9000,'expected_cost_price',5000,'price',1)));
   raise exception 'Sale price accepted';
  exception when invalid_parameter_value then null; end;
  begin
   perform public.yordamchi_update_book_costs(jsonb_build_array(jsonb_build_object('id',b.id,'cost_price',9000,'expected_cost_price',-1)));
   raise exception 'Invalid expected cost accepted';
  exception when invalid_parameter_value then null; end;
  begin
   perform public.yordamchi_update_book_costs(jsonb_build_array(jsonb_build_object('id',b.id,'cost_price',9000,'expected_cost_price',999999999)));
   raise exception 'Concurrent overwrite accepted';
  exception when serialization_failure then null; end;
  raise exception 'Rollback test writes' using errcode='ZX001';
 exception when sqlstate 'ZX001' then null;
 end;
end;
$test$;
select 'passed: only cost_price changed; sale prices and all sales_log rows unchanged; conflicts rejected; test writes rolled back' as verification;
