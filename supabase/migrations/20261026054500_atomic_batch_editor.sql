-- Atomic, idempotent batch editor. All changes target a persisted receipt
-- identity; never append existing batch quantities a second time.
create or replace function public.admin_web_batch_apply_edits(
  p_secret text, p_kind text, p_key text,
  p_changes jsonb default '[]'::jsonb,
  p_additions jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare
 v_group uuid;
 v_import bigint;
 v_day date;
 v_line public.web_book_batches%rowtype;
 v_book uuid;
 v_item jsonb;
 v_existing bigint;
 v_quantity int;
 v_original int;
 v_cost int;
 v_stock int;
 v_price int;
 v_delta int;
 v_updated int:=0;
 v_removed int:=0;
 v_added int:=0;
 v_seen bigint[]:=array[]::bigint[];
 v_added_books uuid[]:=array[]::uuid[];
begin
 if not coalesce(public.admin_verify(p_secret),false) then
  raise exception 'Admin tasdiqlanmadi';
 end if;
 if p_kind not in ('group','import','legacy') then
  raise exception 'Partiya turi noto‘g‘ri';
 end if;
 if p_kind='group' then
  v_group:=p_key::uuid;
  if not exists(select 1 from public.web_batch_groups where id=v_group) then
   raise exception 'Partiya topilmadi';
  end if;
 elsif p_kind='import' then
  v_import:=p_key::bigint;
  if not exists(select 1 from public.web_batch_imports where id=v_import) then
   raise exception 'Xarid qaydi topilmadi';
  end if;
 else
  v_day:=p_key::date;
  if v_day<date '2020-01-01' or v_day>current_date+366 then
   raise exception 'Partiya sanasi noto‘g‘ri';
  end if;
  if not exists(select 1 from public.web_book_batches b
    where b.purchased_at=v_day and b.batch_group_id is null
      and b.batch_import_id is null) then
   raise exception 'Tarixiy partiya topilmadi';
  end if;
 end if;
 if jsonb_typeof(p_changes) is distinct from 'array'
   or jsonb_typeof(p_additions) is distinct from 'array'
   or jsonb_array_length(p_changes)>200 or jsonb_array_length(p_additions)>100
 then raise exception 'Kitoblar ro‘yxati noto‘g‘ri'; end if;

 -- Serialize this entire batch, even across separate administrative devices.
 perform pg_advisory_xact_lock(hashtextextended(
   'batch_editor:'||p_kind||':'||p_key, 20261026));

 for v_item in select value from jsonb_array_elements(p_changes) loop
  v_existing:=(v_item->>'id')::bigint;
  if v_existing is null or v_existing=any(v_seen) then
   raise exception 'Partiya qatori tanlanmagan yoki takrorlangan';
  end if;
  v_seen:=array_append(v_seen,v_existing);
  v_original:=(v_item->>'expected_quantity')::integer;
  v_quantity:=(v_item->>'quantity')::integer;
  if v_quantity is null or v_quantity<0 or v_quantity>10000
     or v_original is null or v_original<1 then
    raise exception 'Kitob soni noto‘g‘ri';
  end if;
  select * into v_line from public.web_book_batches
   where id=v_existing for update;
  if not found then raise exception 'Partiyadagi kitob topilmadi'; end if;
  if (p_kind='group' and v_line.batch_group_id is distinct from v_group)
   or (p_kind='import' and v_line.batch_import_id is distinct from v_import)
   or (p_kind='legacy' and (
        v_line.batch_group_id is not null or
        v_line.batch_import_id is not null or
        v_line.purchased_at is distinct from v_day)) then
   raise exception 'Bu kitob boshqa partiyaga tegishli';
  end if;
  if v_line.quantity<>v_original then
   raise exception 'Partiya boshqa qurilmada o‘zgargan. Sahifani yangilang';
  end if;
  v_delta:=v_quantity-v_line.quantity;
  if v_delta<>0 and v_line.inventory_applied then
   select stock into v_stock from public.books
    where id=v_line.book_id for update;
   if not found or v_stock+v_delta<0 or v_stock+v_delta>99999 then
    raise exception 'Ombor qoldig‘i yetarli emas yoki limit oshadi';
   end if;
   update public.books set stock=stock+v_delta,updated_at=now()
    where id=v_line.book_id;
  end if;
  if v_quantity=0 then
   delete from public.web_book_batches where id=v_line.id;
   v_removed:=v_removed+1;
  elsif v_quantity<>v_original then
   update public.web_book_batches set quantity=v_quantity
    where id=v_line.id;
   v_updated:=v_updated+1;
  end if;
 end loop;

 for v_item in select value from jsonb_array_elements(p_additions) loop
  v_book:=(v_item->>'book_id')::uuid;
  v_quantity:=(v_item->>'quantity')::integer;
  if v_book is null or v_book=any(v_added_books) or
     v_quantity is null or v_quantity<1 or v_quantity>10000 then
   raise exception 'Yangi kitob yoki uning soni noto‘g‘ri';
  end if;
  v_added_books:=array_append(v_added_books,v_book);
  -- Existing line is authoritative even if removed earlier in the transaction:
  -- a replace must use its original ID, not create a duplicate.
  if exists (select 1 from public.web_book_batches b where b.book_id=v_book
     and ((p_kind='group' and b.batch_group_id=v_group)
      or (p_kind='import' and b.batch_import_id=v_import)
      or (p_kind='legacy' and b.purchased_at=v_day
        and b.batch_import_id is null and b.batch_group_id is null))) then
   raise exception 'Kitob bu partiyada allaqachon bor; uning sonini tahrirlang';
  end if;
  select cost_price,price,stock into v_cost,v_price,v_stock
   from public.books where id=v_book for update;
  if not found then raise exception 'Katalogdagi kitob topilmadi'; end if;
  if v_item ? 'unit_cost' then
   v_cost:=(v_item->>'unit_cost')::integer;
  end if;
  if v_cost is null or v_cost<0 or v_cost>100000000 then
   raise exception 'Tan narxi noto‘g‘ri';
  end if;
  if p_kind='group' then
   select batch_date into v_day from public.web_batch_groups where id=v_group;
  elsif p_kind='import' then
   select purchase_date into v_day from public.web_batch_imports where id=v_import;
  end if;
  insert into public.web_book_batches(
    book_id,quantity,unit_cost,suggested_price,purchased_at,
    batch_group_id,batch_import_id,inventory_applied,cost_origin
  ) values (
    v_book,v_quantity,v_cost,v_price,v_day,
    v_group,v_import,false,
    case when v_item ? 'unit_cost' then 'manual' else 'catalog_prefill' end
  );
  -- Adding books to an existing historical batch records the receipt
  -- only. Never create a second stock intake or duplicate finance expense.
  v_added:=v_added+1;
 end loop;

 return jsonb_build_object('saved',true,'updated',v_updated,
   'removed',v_removed,'added',v_added,'inventory_delta_policy',
   'only previously inventory_applied lines change stock');
end $fn$;
revoke all on function public.admin_web_batch_apply_edits(text,text,text,jsonb,jsonb)
 from public,anon,authenticated;
grant execute on function public.admin_web_batch_apply_edits(text,text,text,jsonb,jsonb)
 to anon,authenticated,service_role;
