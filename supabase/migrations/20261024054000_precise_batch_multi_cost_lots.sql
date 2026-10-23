-- Capture individual original cost lots so live calculation exactly
-- matches the server's newest-line-first quantity adjustments.
-- Read-only admin RPC replacement; no customer or finance data changes.
CREATE OR REPLACE FUNCTION public.admin_web_batch_existing_data(p_secret text, p_scope text, p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_import bigint; v_group uuid; v_finance uuid;
  v_revision text; v_items jsonb; v_transports jsonb;
  v_title text;
  v_finance_purchase_total bigint;
  v_import_purchase_total bigint;
  v_import_count integer:=0;
  v_linked_expense_count integer:=0;
  v_exact_book_total bigint:=0;
begin
  if public.admin_verify(p_secret) is not true then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_scope='old_import' then
    v_import:=p_id::bigint;
    select title into v_title from public.web_batch_imports where id=v_import;
  elsif p_scope='old_group' then
    v_group:=p_id::uuid;
    select title into v_title from public.web_batch_groups where id=v_group;
  elsif p_scope='old_finance_group' then
    v_finance:=p_id::uuid;
    select title into v_title from public.web_finance_batch_groups where id=v_finance;
  else
    raise exception 'Partiya turi noto‘g‘ri';
  end if;
  if v_title is null then raise exception 'Partiya topilmadi'; end if;

  select md5(coalesce(jsonb_agg(jsonb_build_object(
     'id',l.id,'quantity',l.quantity,'unit_cost',l.unit_cost)
     order by l.id)::text,'[]')) into v_revision
  from public.web_book_batches l
  left join public.web_batch_imports imp on imp.id=l.batch_import_id
  where (v_import is not null and l.batch_import_id=v_import)
     or (v_group is not null and l.batch_group_id=v_group)
     or (v_finance is not null and imp.finance_group_id=v_finance);

  select coalesce(jsonb_agg(jsonb_build_object(
    'book_id',p.book_id,'title',p.title,
    'quantity',p.quantity,'unit_cost',p.unit_cost,
    'line_value',p.line_value,
    'cost_lots',p.cost_lots,
    'multiple_lines',p.line_count) order by lower(p.title)),'[]'::jsonb)
  into v_items from (
    select l.book_id,min(b.title) title,
      sum(l.quantity)::int quantity,
      round(sum(l.quantity::numeric*l.unit_cost)/nullif(sum(l.quantity),0))::int unit_cost,
      sum(l.quantity::bigint*l.unit_cost)::bigint line_value,
      jsonb_agg(jsonb_build_object('quantity',l.quantity,
        'unit_cost',l.unit_cost) order by l.id desc) cost_lots,
      count(*)::int line_count
    from public.web_book_batches l
    join public.books b on b.id=l.book_id
    left join public.web_batch_imports imp on imp.id=l.batch_import_id
    where (v_import is not null and l.batch_import_id=v_import)
       or (v_group is not null and l.batch_group_id=v_group)
       or (v_finance is not null and imp.finance_group_id=v_finance)
    group by l.book_id
  ) p;

  select coalesce(jsonb_agg(t.finance_expense_id order by t.finance_expense_id),'[]'::jsonb)
  into v_transports from public.web_batch_transport_links t
  left join public.web_batch_imports i on i.id=t.batch_import_id
  where (v_import is not null and t.batch_import_id=v_import)
     or (v_group is not null and t.batch_group_id=v_group)
     or (v_finance is not null and i.finance_group_id=v_finance);

  -- Financial expense belongs to a purchase/import, or a finance-group's
  -- constituent imports. Catalog-only batch groups have NO matching finance
  -- expense and must never be represented as a settled expense.
  if v_import is not null or v_finance is not null then
    select count(*)::int,count(e.id)::int,
      sum(e.amount::bigint),sum(i.total_krw::bigint)
    into v_import_count,v_linked_expense_count,
      v_finance_purchase_total,v_import_purchase_total
    from public.web_batch_imports i
    left join public.finance_expenses e
      on e.id=i.finance_expense_id and e.category='inventory_purchase'
    where (v_import is not null and i.id=v_import)
       or (v_finance is not null and i.finance_group_id=v_finance);
  end if;
  select coalesce(sum((x->>'line_value')::bigint),0)
    into v_exact_book_total from jsonb_array_elements(v_items) x;
  return jsonb_build_object(
    'scope',p_scope,'id',p_id,'title',v_title,
    'revision',v_revision,'items',v_items,'transport_ids',v_transports,
    'finance_purchase_total',case when v_import_count>0
      and v_import_count=v_linked_expense_count
      then v_finance_purchase_total else null end,
    'finance_linked',v_import_count>0 and
      v_import_count=v_linked_expense_count,
    'finance_record_count',v_linked_expense_count,
    'finance_import_count',v_import_count,
    'import_record_total',v_import_purchase_total,
    'book_value_exact',v_exact_book_total);
end;
$function$;
revoke all on function public.admin_web_batch_existing_data(text,text,text) from public;
grant execute on function public.admin_web_batch_existing_data(text,text,text) to anon,authenticated,service_role;
