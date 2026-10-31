CREATE OR REPLACE FUNCTION public.admin_release_preorder(p_secret text, p_source text, p_id text, p_action text DEFAULT 'detail'::text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r jsonb; inv private.release_preorder_invoices%rowtype; x jsonb; l record; b public.books%rowtype;
 st text; q integer; total_qty integer:=0; oid uuid; items jsonb; subtotal bigint;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 perform private.release_preorder_ensure(p_source,p_id);
 r:=private.release_preorder_context(p_source,p_id);
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id for update;
 if p_action='detail' then
   return private.release_preorder_detail(p_source,p_id) ||
     jsonb_build_object('partial_active',
       p_source='web' and exists(select 1 from private.web_preorder_partial_batches
          where preorder_id=p_id::uuid and status<>'cancelled'));
 end if;
 if p_source='web' and exists(select 1 from private.web_preorder_partial_batches
     where preorder_id=p_id::uuid and status<>'cancelled') then
   raise exception 'Bu zakas qisman hisobda. Eski yakuniy hisob va bekor qilish tugmasini ishlatmang';
 end if;
 if p_payload?'revision' and (p_payload->>'revision')::bigint<>inv.revision then raise exception 'Zakas o‘zgargan. Yangilang'; end if;
 if p_action='status' then
  st:=p_payload->>'status';
  if st not in ('accepted','contacted','cancelled') then raise exception 'Holat noto‘g‘ri'; end if;
  if inv.payment_state='cancelled' then raise exception 'Bekor zakas qayta ochilmaydi; yangi zakas yarating'; end if;
  if st='cancelled' then perform private.release_cancel_preorder(p_source,p_id); end if;
  if p_source='native' then update public.preorders set status=st where id=p_id::bigint;
  else update public.web_preorder_requests set status=st,updated_at=now(),status_version=status_version+1 where id=p_id::uuid; end if;
  -- A stock-neutral update also allocates inventory that arrived earlier.
  if st in ('accepted','contacted') then
   for l in select distinct book_id from private.release_preorder_lines where source=p_source and reference=p_id order by book_id loop
    update public.books set stock=stock where id=l.book_id;
   end loop;
  end if;
 elsif p_action='invoice' then
  if inv.payment_state<>'requested' or r->>'status'='cancelled' then raise exception 'To‘lov yoki bekordan keyin narxni o‘zgartirib bo‘lmaydi'; end if;
  if jsonb_typeof(p_payload->'items')<>'array' or jsonb_array_length(p_payload->'items') not between 1 and 50 then raise exception 'Har bir asosiy kitob va narxni kiriting'; end if;
  -- Release the old main allocation before atomically replacing the invoice.
  for l in select * from private.release_preorder_lines where source=p_source and reference=p_id and kind='main' order by book_id for update loop
   delete from private.release_preorder_lines where source=p_source and reference=p_id and kind='main' and book_id=l.book_id;
   if l.held>0 then update public.books set stock=stock+l.held where id=l.book_id; end if;
  end loop;
  for x in select * from jsonb_array_elements(p_payload->'items') order by value->>'book_id' loop
   q:=(x->>'quantity')::integer;
   if q not between 1 and 200 or (x->>'unit_price')::integer not between 1 and 10000000 then raise exception 'Kitob miqdori yoki narxi noto‘g‘ri'; end if;
   select * into b from public.books where id=(x->>'book_id')::uuid for update;
   if not found or b.stock<q then raise exception 'Asosiy kitob omborda yetarli emas. Avval partiyani kiriting'; end if;
   insert into private.release_preorder_lines values(p_source,p_id,'main',b.id,b.title,q,(x->>'unit_price')::integer,coalesce(b.cost_price,0),q);
   update public.books set stock=stock-q where id=b.id;
   total_qty:=total_qty+q;
  end loop;
  if total_qty<>(r->>'quantity')::integer then raise exception 'Asosiy kitoblar soni zakasdagi songa mos emas'; end if;
  update private.release_preorder_invoices set price_ready=true,admin_note=left(trim(coalesce(p_payload->>'note','')),500) where source=p_source and reference=p_id;
  perform private.release_preorder_recalculate(p_source,p_id);
  if p_source='native' then update public.preorders set status='arrived' where id=p_id::bigint;
  else update public.web_preorder_requests set status='arrived',updated_at=now(),status_version=status_version+1 where id=p_id::uuid; end if;
  if nullif(trim(r->>'phone'),'') is not null then
   insert into public.customer_push_messages(phone,title,body,kind) values(r->>'phone','Oldindan zakasingiz keldi 📚','Yakuniy hisob va avans ayirilgan qolgan summani Oldindan zakaslarim bo‘limida tekshiring.','preorder_balance');
  end if;
 elsif p_action='confirm' then
  if inv.converted_order_id is not null then return private.release_preorder_detail(p_source,p_id); end if;
  if r->>'status'<>'arrived' or not inv.price_ready or not inv.delivery_saved or
   (inv.amount_due>0 and inv.payment_state<>'proof_submitted') or inv.payment_state='cancelled' then raise exception 'Narx, manzil va qolgan to‘lovni tekshiring'; end if;
  if not exists(select 1 from private.release_preorder_lines where source=p_source and reference=p_id and kind='main') or
   exists(select 1 from private.release_preorder_lines where source=p_source and reference=p_id and held<>quantity) then raise exception 'Barcha kitoblar band qilinmagan'; end if;
  oid:=gen_random_uuid();
  select jsonb_agg(jsonb_build_object('book_id',book_id,'title',title,'quantity',quantity,'price',unit_price,'unit_price',unit_price,'unit_cost',unit_cost,'line_total',quantity::bigint*unit_price) order by kind,book_id),sum(quantity::bigint*unit_price)
   into items,subtotal from private.release_preorder_lines where source=p_source and reference=p_id;
  insert into private.release_conversion_orders(order_id,source,reference,items,subtotal,delivery_fee) values(oid,p_source,p_id,items,subtotal::integer,inv.shipping_fee);
  insert into public.orders(id,customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,status,source,items,stock_reserved,payment_proof_path,payment_submitted_at,order_note,entered_by_admin,payment_status)
   values(oid,inv.recipient_name,inv.recipient_phone,inv.delivery_address,inv.delivery_type,inv.shipping_fee,subtotal::integer,(subtotal+inv.shipping_fee)::integer,'new','app',items,true,inv.balance_proof_path,now(),
   'Oldindan zakas '||p_source||':'||p_id||'; avans '||inv.deposit_credit::text,false,'paid');
  insert into private.release_order_owners(order_id,phone_key) values(oid,public._customer_phone_key(r->>'phone')) on conflict do nothing;
  perform public.admin_accept_order_with_note(p_secret,oid,inv.admin_note);
  update private.release_preorder_invoices set balance_paid=submitted_amount,amount_due=0,payment_state='verified',converted_order_id=oid,revision=revision+1,updated_at=now() where source=p_source and reference=p_id;
  -- The normal order now owns the allocation, including cancellation/restock.
  update private.release_preorder_lines set held=0 where source=p_source and reference=p_id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.release_preorder_detail(p_source,p_id);
end $function$


create or replace function private.web_partial_cancel_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status='cancelled' and old.status is distinct from new.status and
    exists(select 1 from private.web_preorder_partial_batches b
      where b.preorder_id=new.id and b.status<>'cancelled') then
    raise exception 'Bu zakasning qisman avansi ajratilgan. Eski bekor qilish amali yopiq';
 end if;
 return new;
end $$;
drop trigger if exists web_partial_cancel_guard on public.web_preorder_requests;
create trigger web_partial_cancel_guard before update of status
on public.web_preorder_requests for each row execute function private.web_partial_cancel_guard();
