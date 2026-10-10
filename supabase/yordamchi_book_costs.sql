-- Narrow service-only write endpoint. It cannot accept or update sale prices.
create or replace function public.yordamchi_update_book_costs(p_changes jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  item jsonb;
  book public.books%rowtype;
  result jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_changes) is distinct from 'array' or jsonb_array_length(p_changes) not between 1 and 300 then
    raise exception 'Invalid changes' using errcode='22023';
  end if;
  for item in select value from jsonb_array_elements(p_changes) loop
    if jsonb_typeof(item) is distinct from 'object'
      or not (item ?& array['id','cost_price','expected_cost_price'])
      or (item - array['id','cost_price','expected_cost_price']) <> '{}'::jsonb
      or jsonb_typeof(item->'id') is distinct from 'string'
      or (item->>'id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(item->'cost_price') is distinct from 'number'
      or (item->>'cost_price') !~ '^[0-9]+$'
      or (item->>'cost_price')::numeric > 1000000000
      or (jsonb_typeof(item->'expected_cost_price') is distinct from 'null' and
         (jsonb_typeof(item->'expected_cost_price') is distinct from 'number'
          or (item->>'expected_cost_price') !~ '^[0-9]+$'
          or (item->>'expected_cost_price')::numeric > 2147483647)) then
      raise exception 'Only id, cost_price and expected_cost_price are allowed' using errcode='22023';
    end if;
  end loop;
  if (select count(distinct value->>'id') from jsonb_array_elements(p_changes)) <> jsonb_array_length(p_changes) then
    raise exception 'Duplicate book' using errcode='22023';
  end if;
  -- Deterministic lock ordering; a conflict rolls back the entire batch.
  for item in select value from jsonb_array_elements(p_changes) order by value->>'id' loop
    select * into book from public.books where id=(item->>'id')::uuid for update;
    if not found then raise exception 'Book no longer exists' using errcode='P0002'; end if;
    if book.cost_price is distinct from (item->>'expected_cost_price')::integer then
      raise exception 'Cost changed; refresh first' using errcode='40001';
    end if;
    if book.cost_price is distinct from (item->>'cost_price')::integer then
      update public.books set cost_price=(item->>'cost_price')::integer where id=book.id;
    end if;
    result := result || jsonb_build_array(jsonb_build_object('id',book.id,'cost_price',(item->>'cost_price')::integer));
  end loop;
  return result;
end;
$function$;
revoke all on function public.yordamchi_update_book_costs(jsonb) from public, anon, authenticated;
grant execute on function public.yordamchi_update_book_costs(jsonb) to service_role;
