-- One-batch QA: edit a historical batch by its ABSOLUTE quantity.
-- The inventory and finance ledgers are deliberately not touched.
-- Before modifying any old line, save its full row into a private audit log.
create table if not exists private.web_batch_edit_audit (
  id bigint generated always as identity primary key,
  changed_at timestamptz not null default now(),
  scope text not null,
  target_id text not null,
  book_id uuid not null,
  original_rows jsonb not null,
  requested_quantity integer not null,
  edited_unit_cost integer,
  previous_revision text not null
);
revoke all on private.web_batch_edit_audit from public,anon,authenticated;

create or replace function public.admin_web_batch_existing_data(
  p_secret text, p_scope text, p_id text)
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare
  v_import bigint; v_group uuid; v_finance uuid;
  v_revision text; v_items jsonb; v_transports jsonb;
  v_title text;
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
    'multiple_lines',p.line_count) order by lower(p.title)),'[]'::jsonb)
  into v_items from (
    select l.book_id,min(b.title) title,
      sum(l.quantity)::int quantity,
      round(sum(l.quantity::numeric*l.unit_cost)/nullif(sum(l.quantity),0))::int unit_cost,
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

  return jsonb_build_object('scope',p_scope,'id',p_id,'title',v_title,
      'revision',v_revision,'items',v_items,'transport_ids',v_transports);
end;
$function$;

create or replace function public.admin_web_batch_edit_existing(
  p_secret text, p_scope text,p_id text,
  p_expected_revision text,p_items jsonb,
  p_transport_ids jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare
  v_import bigint; v_group uuid; v_finance uuid;
  v_scope jsonb; v_revision text;
  v_item jsonb; v_book uuid; v_qty int; v_cost int; v_old_qty int;
  v_delta int; v_remaining int; v_existing int; v_book_count int:=0;
  v_cost_edit boolean;
  v_date date; v_stock int; v_suggested int;
  v_line record; v_rows jsonb;
  v_seen uuid[]:='{}'::uuid[];
  v_finance_expense uuid; v_new_transports int:=0;
  v_transport_import bigint;
begin
  if public.admin_verify(p_secret) is not true then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_scope not in ('old_import','old_group','old_finance_group') then
    raise exception 'Partiya turi noto‘g‘ri';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or
      jsonb_array_length(p_items)>100 or
      jsonb_typeof(p_transport_ids) is distinct from 'array' or
      jsonb_array_length(p_transport_ids)>50 then
    raise exception 'Kitob yoki transport ro‘yxati noto‘g‘ri';
  end if;
  -- Serialize edits to the SAME historical batch. Do not let a stale
  -- already-open screen overwrite another administrator's correction.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('historical-batch:'||p_scope||':'||p_id,0));
  v_scope:=public.admin_web_batch_existing_data(p_secret,p_scope,p_id);
  v_revision:=v_scope->>'revision';
  if p_expected_revision is distinct from v_revision then
    raise exception 'Partiya boshqa joyda o‘zgargan. Qayta ochib tekshiring.';
  end if;
  if p_scope='old_import' then
    v_import:=p_id::bigint;
    select purchase_date into v_date from public.web_batch_imports where id=v_import;
  elsif p_scope='old_group' then
    v_group:=p_id::uuid;
    select batch_date into v_date from public.web_batch_groups where id=v_group;
  else
    v_finance:=p_id::uuid;
    select id,purchase_date into v_import,v_date
      from public.web_batch_imports where finance_group_id=v_finance
      order by purchase_date desc,id desc limit 1;
    if v_import is null then raise exception 'Moliya partiyasida import topilmadi'; end if;
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_book:=(v_item->>'book_id')::uuid;
    v_qty:=(v_item->>'quantity')::integer;
    v_cost:=(v_item->>'unit_cost')::integer;
    v_cost_edit:=coalesce((v_item->>'edited_cost')::boolean,false);
    if v_book is null or v_book=any(v_seen)
      or v_qty is null or v_qty<0 or v_qty>10000
      or v_cost is null or v_cost<0 or v_cost>100000000 then
      raise exception 'Kitob, miqdor yoki tannarx noto‘g‘ri';
    end if;
    v_seen:=array_append(v_seen,v_book);
    select price,stock into v_suggested,v_stock from public.books
       where id=v_book;
    if not found then raise exception 'Kitob katalogdan topilmadi'; end if;
    select coalesce(sum(l.quantity),0)::int,count(*)::int,
      coalesce(jsonb_agg(to_jsonb(l) order by l.id),'[]'::jsonb)
      into v_old_qty,v_existing,v_rows
    from public.web_book_batches l
    left join public.web_batch_imports i on i.id=l.batch_import_id
    where l.book_id=v_book and (
      (p_scope='old_import' and l.batch_import_id=v_import)
      or (p_scope='old_group' and l.batch_group_id=v_group)
      or (p_scope='old_finance_group' and i.finance_group_id=v_finance));

    if v_qty=v_old_qty and (not v_cost_edit or v_existing=0) then
      continue;
    end if;
    insert into private.web_batch_edit_audit(
      scope,target_id,book_id,original_rows,requested_quantity,edited_unit_cost,previous_revision)
    values(p_scope,p_id,v_book,v_rows,v_qty,
      case when v_cost_edit then v_cost else null end,v_revision);

    v_delta:=v_qty-v_old_qty;
    if v_delta>0 then
      if v_existing>0 then
        update public.web_book_batches set quantity=quantity+v_delta
        where id=(select max(l.id) from public.web_book_batches l
          left join public.web_batch_imports i on i.id=l.batch_import_id
          where l.book_id=v_book and (
           (p_scope='old_import' and l.batch_import_id=v_import)
           or (p_scope='old_group' and l.batch_group_id=v_group)
           or (p_scope='old_finance_group' and i.finance_group_id=v_finance)));
      else
        insert into public.web_book_batches(
          book_id,quantity,unit_cost,suggested_price,purchased_at,
          batch_import_id,batch_group_id,cost_origin,note)
        values(v_book,v_qty,v_cost,v_suggested,v_date,v_import,v_group,
           case when v_cost_edit then 'manual' else 'catalog_prefill' end,
           'Eski partiya miqdorini tahrirlash orqali kiritilgan');
      end if;
    elsif v_delta<0 then
      v_remaining:=-v_delta;
      for v_line in
        select l.id,l.quantity from public.web_book_batches l
        left join public.web_batch_imports i on i.id=l.batch_import_id
        where l.book_id=v_book and (
         (p_scope='old_import' and l.batch_import_id=v_import)
         or (p_scope='old_group' and l.batch_group_id=v_group)
         or (p_scope='old_finance_group' and i.finance_group_id=v_finance))
        order by l.id desc for update of l
      loop
        if v_remaining=0 then exit; end if;
        if v_line.quantity<=v_remaining then
          delete from public.web_book_batches where id=v_line.id;
          v_remaining:=v_remaining-v_line.quantity;
        else
          update public.web_book_batches
            set quantity=quantity-v_remaining where id=v_line.id;
          v_remaining:=0;
        end if;
      end loop;
      if v_remaining<>0 then raise exception 'Partiya qoldig‘i mos emas'; end if;
    end if;

    if v_cost_edit and v_qty>0 then
      update public.web_book_batches l set
        unit_cost=v_cost,cost_origin='manual'
      from public.web_batch_imports i
      where l.book_id=v_book and
        ((p_scope='old_import' and l.batch_import_id=v_import)
        or (p_scope='old_group' and l.batch_group_id=v_group)
        or (p_scope='old_finance_group' and l.batch_import_id=i.id
            and i.finance_group_id=v_finance));
      -- The FROM join above can omit group rows with no import ID.
      if p_scope='old_group' then
        update public.web_book_batches
          set unit_cost=v_cost,cost_origin='manual'
          where book_id=v_book and batch_group_id=v_group;
      end if;
    end if;
    v_book_count:=v_book_count+1;
  end loop;

  for v_item in select value from jsonb_array_elements(p_transport_ids) loop
    v_finance_expense:=(trim(both '"' from v_item::text))::uuid;
    if v_finance_expense is null then raise exception 'Transport ID noto‘g‘ri'; end if;
    if exists(select 1 from public.web_batch_transport_links
       where finance_expense_id=v_finance_expense) then
      -- Existing association is already counted, never add a duplicate.
      if exists(select 1 from public.web_batch_transport_links l
         left join public.web_batch_imports i on i.id=l.batch_import_id
         where l.finance_expense_id=v_finance_expense and
          ((p_scope='old_import' and l.batch_import_id=v_import)
          or (p_scope='old_group' and l.batch_group_id=v_group)
          or (p_scope='old_finance_group' and i.finance_group_id=v_finance))) then
        continue;
      end if;
      raise exception 'Transport boshqa partiyaga biriktirilgan';
    end if;
    perform 1 from public.finance_expenses where id=v_finance_expense
       and category='transport' for update;
    if not found then raise exception 'Transport topilmadi'; end if;
    insert into public.web_batch_transport_links(finance_expense_id,batch_import_id,batch_group_id)
      values(v_finance_expense,v_import,v_group);
    v_new_transports:=v_new_transports+1;
  end loop;
  return jsonb_build_object('saved',true,'edited_titles',v_book_count,
    'transport_added',v_new_transports,'inventory_updated',false,
    'finance_updated',false);
end;
$function$;

revoke all on function public.admin_web_batch_existing_data(text,text,text)
 from public;
grant execute on function public.admin_web_batch_existing_data(text,text,text)
 to anon,authenticated,service_role;
revoke all on function public.admin_web_batch_edit_existing(text,text,text,text,jsonb,jsonb)
 from public;
grant execute on function public.admin_web_batch_edit_existing(text,text,text,text,jsonb,jsonb)
 to anon,authenticated,service_role;

-- The former finance-group dropdown pointed at ONE arbitrary child import;
-- choose the true parent group ID so all historical books are editable.
CREATE OR REPLACE FUNCTION public.admin_web_batch_picker_data(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if not coalesce(public.admin_verify(p_secret),false) then
   raise exception 'Admin tasdiqlanmadi';
 end if;
 return jsonb_build_object(
  'books',coalesce((select jsonb_agg(jsonb_build_object(
       'id',b.id,'title',b.title,'cost_price',b.cost_price,
       'price',b.price,'stock',b.stock,'is_active',b.is_active)
       order by lower(b.title))
       from public.books b),'[]'::jsonb),
  'historical',coalesce((
    select jsonb_agg(h.record order by h.sort_date desc,h.sort_id desc)
    from (
      select g.batch_date as sort_date, 0::bigint as sort_id,
        jsonb_build_object(
          'id',g.id,
          'title',g.title,'purchase_date',g.batch_date,
          'total_krw',(select sum(coalesce(f.amount,p.total_krw))
              from public.web_batch_imports p
              left join public.finance_expenses f on f.id=p.finance_expense_id
              where p.finance_group_id=g.id),
          'source','finance_group'
        ) as record
      from public.web_finance_batch_groups g
      where exists(select 1 from public.web_batch_imports p
        where p.finance_group_id=g.id)
      union all
      select p.purchase_date,p.id,
        jsonb_build_object('id',p.id,'title',p.title,
          'purchase_date',p.purchase_date,
          'total_krw',coalesce(f.amount,p.total_krw),
          'source',p.source)
      from public.web_batch_imports p
      left join public.finance_expenses f on f.id=p.finance_expense_id
      where p.finance_group_id is null
    ) h
  ),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(
      jsonb_build_object('id',g.id,'title',g.title,'batch_date',g.batch_date)
      order by g.batch_date desc,g.created_at desc)
      from public.web_batch_groups g),'[]'::jsonb),
  'transports',coalesce((select jsonb_agg(
    jsonb_build_object(
      'id',e.id,'expense_date',e.expense_date,
      'amount',e.amount,'note',e.note,'source',e.source,
      'batch_import_id',l.batch_import_id,'batch_group_id',l.batch_group_id,
      'linked_to',coalesce(fg.title,p.title,g.title),
      'linked_at',l.linked_at
    ) order by e.expense_date desc,e.created_at desc)
    from public.finance_expenses e
    left join public.web_batch_transport_links l on l.finance_expense_id=e.id
    left join public.web_batch_imports p on p.id=l.batch_import_id
    left join public.web_finance_batch_groups fg on fg.id=p.finance_group_id
    left join public.web_batch_groups g on g.id=l.batch_group_id
    where e.category='transport'),'[]'::jsonb)
 );
end; $function$;
revoke all on function public.admin_web_batch_picker_data(text) from public;
grant execute on function public.admin_web_batch_picker_data(text) to anon,authenticated,service_role;
