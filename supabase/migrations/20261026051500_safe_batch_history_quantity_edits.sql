-- Editable registered book batches, with optimistic locking and stock delta only.
-- Historical entries have no verified inventory mutation provenance.
-- Keep them unflagged to avoid accidental repeated stock change.
alter table public.web_book_batches
 add column if not exists inventory_applied boolean not null default false;

-- New batch entries remember whether initial stock was changed.
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
 return jsonb_build_object('saved',true,'items',v_saved,
   'transport_items',v_transport_count,'inventory_updated',v_apply,
   'new_group_id',v_group,'historical_id',v_import);
end; $function$


-- Return the persisted value on subsequent visits to the batch editor.
;
CREATE OR REPLACE FUNCTION public.admin_web_batch_line_list(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not coalesce(public.admin_verify(p_secret),false) then
   raise exception 'Admin tasdiqlanmadi';
 end if;
 return coalesce((
  select jsonb_agg(
    jsonb_build_object('id',l.id,'book_id',l.book_id,'title',b.title,
      'quantity',l.quantity,'unit_cost',l.unit_cost,
      'suggested_price',l.suggested_price,'purchased_at',l.purchased_at,
      'note',l.note,'cost_origin',l.cost_origin,
      'inventory_applied',l.inventory_applied,'batch_import_id',l.batch_import_id,'batch_group_id',l.batch_group_id,
      'batch_name',coalesce(g.title,i.title,'Alohida partiya'),
      'batch_type',case when l.batch_import_id is not null then 'finance'
        when l.batch_group_id is not null then 'catalog' else 'legacy' end)
    order by l.purchased_at desc,l.id desc)
  from public.web_book_batches l
  join public.books b on b.id=l.book_id
  left join public.web_batch_imports i on i.id=l.batch_import_id
  left join public.web_batch_groups g on g.id=l.batch_group_id
 ),'[]'::jsonb);
end; $function$


;
create or replace function public.admin_web_batch_edit_line(
 p_secret text, p_line_id bigint, p_expected_quantity integer, p_quantity integer
) returns jsonb
 language plpgsql security definer set search_path='' as $function$
declare
 v_line public.web_book_batches%rowtype;
 v_current_stock integer;
 v_delta integer;
begin
 if not coalesce(public.admin_verify(p_secret),false) then
   raise exception 'Admin tasdiqlanmadi';
 end if;
 if p_line_id is null or p_expected_quantity is null or
    p_quantity is null or p_quantity<1 or p_quantity>10000 then
   raise exception 'Miqdor 1 dan 10000 gacha bo‘lishi kerak';
 end if;
 select * into v_line from public.web_book_batches
  where id=p_line_id for update;
 if not found then raise exception 'Partiya kitobi topilmadi'; end if;
 if v_line.quantity<>p_expected_quantity then
   raise exception 'Partiya boshqa qurilmada o‘zgargan. Yangilang va qayta urinib ko‘ring.';
 end if;
 v_delta:=p_quantity-v_line.quantity;
 if v_delta<>0 and v_line.inventory_applied then
   select stock into v_current_stock from public.books
     where id=v_line.book_id for update;
   if not found then raise exception 'Ombordagi kitob topilmadi'; end if;
   if v_current_stock+v_delta<0 then
     raise exception 'Omborda bu o‘zgarish uchun yetarli qoldiq yo‘q';
   end if;
   if v_current_stock+v_delta>99999 then
     raise exception 'Ombor limiti oshib ketadi';
   end if;
   update public.books set stock=stock+v_delta,updated_at=now()
     where id=v_line.book_id;
 end if;
 if v_delta<>0 then
   update public.web_book_batches set quantity=p_quantity where id=v_line.id;
 end if;
 return jsonb_build_object(
   'saved',true,'line_id',v_line.id,'quantity',p_quantity,
   'previous_quantity',v_line.quantity,'delta',v_delta,
   'inventory_updated',v_line.inventory_applied and v_delta<>0,
   'inventory_applied',v_line.inventory_applied);
end $function$;
revoke execute on function public.admin_web_batch_edit_line(text,bigint,integer,integer)
 from public,anon,authenticated;
grant execute on function public.admin_web_batch_edit_line(text,bigint,integer,integer)
 to anon,authenticated,service_role;
