-- Prevent historical finance expenses from being linked to a second
-- batch and counted again. No historical rows or amounts are changed.
CREATE OR REPLACE FUNCTION public.admin_web_bulk_batch_save(p_secret text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_mode text := p_data->>'mode';
 v_apply boolean := coalesce((p_data->>'apply_to_inventory')::boolean,false);
 v_lines jsonb := coalesce(p_data->'items','[]'::jsonb);
 v_transports jsonb := coalesce(p_data->'transport_ids','[]'::jsonb);
 v_finance_options jsonb := coalesce(p_data->'finance_expense_ids','[]'::jsonb);
 v_finance_seen uuid[]:=array[]::uuid[];
 v_entry jsonb;
 v_expense uuid;
 v_id uuid;
 v_group uuid;
 v_import bigint;
 v_date date;
 v_title text;
 v_qty int;
 v_cost int;
 v_price int;
 v_stock int;
 v_saved int := 0;
 v_transport_count int := 0;
 v_affected uuid[] := '{}'::uuid[];
 v_expense_amount int;
begin
 if not coalesce(public.admin_verify(p_secret),false) then raise exception 'Admin tasdiqlanmadi'; end if;
 if v_mode not in ('new','old_import','old_group') then raise exception 'Partiya turi noto‘g‘ri'; end if;
 if jsonb_typeof(v_lines) is distinct from 'array' or jsonb_array_length(v_lines)>100 then
   raise exception '100 tagacha kitob belgilang';
 end if;
 if jsonb_typeof(v_transports) is distinct from 'array' or jsonb_array_length(v_transports)>50 then
   raise exception 'Transport tanlovi noto‘g‘ri';
 end if;
 if jsonb_typeof(v_finance_options) is distinct from 'array' or jsonb_array_length(v_finance_options)>40 then
   raise exception 'Moliyadan tanlangan xarajatlar noto‘g‘ri';
 end if;
 if v_mode='new' and jsonb_array_length(v_transports)>0 then
   raise exception 'Yangi partiyada transportni Moliya xarajatlari ro‘yxatidan tanlang';
 end if;
 if v_mode<>'new' and jsonb_array_length(v_finance_options)>0 then
   raise exception 'Bu xarajatlarni faqat yangi partiyada tanlash mumkin';
 end if;
 if jsonb_array_length(v_lines)=0 and jsonb_array_length(v_transports)=0 then
   raise exception 'Kitob yoki transport xarajatini tanlang';
 end if;
 if v_mode = 'new' and jsonb_array_length(v_lines)=0 then
   raise exception 'Yangi partiyaga kamida bitta kitob tanlang';
 end if;
 if v_mode <> 'new' and v_apply then
   raise exception 'Eski partiyada omborga qayta qo‘shib bo‘lmaydi';
 end if;
 if v_mode='new' then
   v_title := left(trim(coalesce(p_data->>'title','')),180);
   if v_title='' then raise exception 'Partiya nomini kiriting'; end if;
   v_date := coalesce(nullif(p_data->>'date','')::date,(now() at time zone 'Asia/Seoul')::date);
   if v_date < date '2020-01-01' or v_date > current_date + 366 then
     raise exception 'Sana noto‘g‘ri';
   end if;
   insert into public.web_batch_groups(title,batch_date,note)
   values(v_title,v_date,left(coalesce(p_data->>'note',''),300))
   returning id into v_group;
 elsif v_mode='old_import' then
   v_import := (p_data->>'existing_id')::bigint;
   select purchase_date into v_date from public.web_batch_imports where id=v_import;
   if not found then raise exception 'Eski partiya topilmadi'; end if;
 else
   v_group := (p_data->>'existing_id')::uuid;
   select batch_date into v_date from public.web_batch_groups where id=v_group;
   if not found then raise exception 'Eski partiya topilmadi'; end if;
 end if;
 for v_entry in select value from jsonb_array_elements(v_lines) loop
   v_id := (v_entry->>'book_id')::uuid;
   if v_id is null or v_id = any(v_affected) then
     raise exception 'Kitob takrorlangan yoki tanlanmagan';
   end if;
   v_affected := array_append(v_affected,v_id);
   v_qty := (v_entry->>'quantity')::int;
   if v_qty is null or v_qty<1 or v_qty>10000 then raise exception 'Miqdor noto‘g‘ri'; end if;
   select stock,price,cost_price into v_stock,v_price,v_cost
     from public.books where id=v_id for update;
   if not found then raise exception 'Katalogda kitob topilmadi'; end if;
   if v_entry ? 'unit_cost' and nullif(v_entry->>'unit_cost','') is not null then
      v_cost := (v_entry->>'unit_cost')::integer;
   end if;
   if v_cost < 0 or v_cost>100000000 then raise exception 'Tannarx noto‘g‘ri'; end if;
   if v_apply and v_stock+v_qty>99999 then raise exception 'Ombor limiti oshdi'; end if;
   if v_mode <> 'new' and exists (
      select 1 from public.web_book_batches existing
       where existing.book_id=v_id and
         ((v_import is not null and existing.batch_import_id=v_import) or
          (v_group is not null and existing.batch_group_id=v_group))
   ) then
      raise exception 'Bu kitob partiyada allaqachon bor. Sonini partiya tarixidan tahrirlang.';
   end if;
   insert into public.web_book_batches(
     book_id,quantity,unit_cost,suggested_price,purchased_at,
     batch_import_id,batch_group_id,cost_origin,note,inventory_applied)
     values(v_id,v_qty,v_cost,v_price,v_date,v_import,v_group,
       case when coalesce((v_entry->>'edited_cost')::boolean,false) then 'manual'
       else 'catalog_prefill' end,left(coalesce(v_entry->>'note',''),300),v_apply);
   if v_apply then
     update public.books set stock=stock+v_qty,cost_price=v_cost,
       restocked_at=now(),updated_at=now() where id=v_id;
   end if;
   v_saved := v_saved+1;
 end loop;
 for v_entry in select value from jsonb_array_elements(v_transports) loop
   v_expense := trim(both '"' from v_entry::text)::uuid;
   if v_expense is null or v_expense = any(v_affected) then
     raise exception 'Transport takrorlangan';
   end if;
   v_affected := array_append(v_affected,v_expense);
   select amount into v_expense_amount from public.finance_expenses
      where id=v_expense and category='transport' for update;
   if not found then raise exception 'Transport xarajati topilmadi yoki turi noto‘g‘ri'; end if;
   if exists(select 1 from public.web_batch_transport_links
      where finance_expense_id=v_expense) then
     raise exception 'Bu transport avval boshqa partiyaga biriktirilgan';
   end if;
   insert into public.web_batch_transport_links(finance_expense_id,batch_import_id,batch_group_id)
     values(v_expense,v_import,v_group);
   v_transport_count := v_transport_count + 1;
 end loop;
 if v_mode='new' then
   for v_entry in select value from jsonb_array_elements(v_finance_options) loop
     v_expense:=trim(both '"' from v_entry::text)::uuid;
     if v_expense is null or v_expense=any(v_finance_seen) then
       raise exception 'Xarajat ikki marta tanlangan';
     end if;
     v_finance_seen:=array_append(v_finance_seen,v_expense);
     perform 1 from public.finance_expenses e
       where e.id=v_expense and e.category in ('inventory_purchase','transport')
       for update;
     if not found then
       raise exception 'Moliya xarajati topilmadi yoki turi noto‘g‘ri';
     end if;
     -- This historical expense may be shown for comparison, but must
     -- never be assigned to a second batch: otherwise reports double count.
     if exists(select 1 from public.web_batch_imports i
         where i.finance_expense_id=v_expense)
       or exists(select 1 from public.web_batch_transport_links tl
         where tl.finance_expense_id=v_expense) then
       raise exception 'Bu xarajat avvalgi partiyaga bog‘langan. '
         'O‘sha partiyaning taqqoslash hisobotini ko‘ring';
     end if;
     if exists(select 1 from public.web_batch_finance_links l
       where l.finance_expense_id=v_expense) then
       raise exception 'Bu xarajat boshqa yangi partiyaga biriktirilgan';
     end if;
     insert into public.web_batch_finance_links(finance_expense_id,batch_group_id)
       values(v_expense,v_group);
   end loop;
 end if;
 return jsonb_build_object('saved',true,'items',v_saved,
   'transport_items',v_transport_count,'inventory_updated',v_apply,
   'finance_references',cardinality(v_finance_seen),
   'new_group_id',v_group,'historical_id',v_import);
end; $function$;
