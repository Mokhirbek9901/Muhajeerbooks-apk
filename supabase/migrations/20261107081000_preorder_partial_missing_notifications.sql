-- Partial preorder arrival and separate missing-book notices.
-- Additive, no mutation of existing preorder item lists or historical deposits.
-- Keep already published iOS / Android binaries compatible.
create table if not exists private.web_preorder_missing_marks (
  preorder_id uuid not null references public.web_preorder_requests(id) on delete cascade,
  item_index integer not null check(item_index>=0 and item_index<50),
  quantity integer not null check(quantity between 1 and 200),
  created_at timestamptz not null default now(),
  primary key(preorder_id,item_index)
);
alter table private.web_preorder_missing_marks enable row level security;
revoke all on private.web_preorder_missing_marks from public, anon, authenticated;

-- Admin mark-missing and original reserve/settle actions share a locked record.
CREATE OR REPLACE FUNCTION public.admin_web_preorder_partial(p_secret text, p_id uuid, p_action text DEFAULT 'detail'::text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare w public.web_preorder_requests%rowtype; old private.web_preorder_partial_batches%rowtype;
 x jsonb; line jsonb; selected jsonb:='[]'::jsonb; b public.books%rowtype;
 ix integer; q integer; price integer; used_qty integer; sum_total bigint:=0;
 bid uuid; receipt_items jsonb; oid uuid; order_total bigint; total_qty integer;
 evt uuid; evt_version integer; notice text;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 perform pg_advisory_xact_lock(hashtextextended('partial:'||p_id::text,28));
 select * into w from public.web_preorder_requests where id=p_id for update;
 if not found then raise exception 'Buyurtma topilmadi'; end if;
 if p_action='detail' then return private.web_preorder_partial_detail(p_id); end if;
 if p_action='prepare' then
   if w.status='cancelled' or jsonb_array_length(w.request_items)<2 then raise exception 'Qisman tayyorlash faqat faol ko‘p kitobli zakasga tegishli'; end if;
   if exists(select 1 from private.web_preorder_partial_batches where preorder_id=p_id and status in ('prepared','awaiting_payment','proof_submitted'))
      or exists(select 1 from private.web_preorder_partial_batches where preorder_id=p_id and status='completed' and choice='all')
      then raise exception 'Avvalgi qisman hisobni tugating yoki yopilgan zakasni tekshiring'; end if;
   if exists(select 1 from private.release_preorder_invoices where source='web' and reference=p_id::text and (price_ready or payment_state<>'requested' or converted_order_id is not null))
      then raise exception 'Eski yakuniy hisob ochilgan. Ikkita hisobni birlashtirib bo‘lmaydi'; end if;
   if jsonb_typeof(p_payload->'items')<>'array' or jsonb_array_length(p_payload->'items') not between 1 and 50
      then raise exception 'Kelgan kitoblarni tanlang'; end if;
   for x in select value from jsonb_array_elements(p_payload->'items') loop
     ix:=(x->>'index')::integer; q:=(x->>'quantity')::integer;
     price:=(x->>'unit_price')::integer; bid:=(x->>'book_id')::uuid;
     if ix is null or ix<0 or ix>=jsonb_array_length(w.request_items) or q not between 1 and 200 or price not between 1 and 10000000
       then raise exception 'Kitob soni yoki narxi noto‘g‘ri'; end if;
     if exists(select 1 from jsonb_array_elements(selected) y where (y->>'index')::integer=ix)
       then raise exception 'Bitta kitobni ikki marta belgilamang'; end if;
     select coalesce(sum((y->>'quantity')::int),0) into used_qty
       from private.web_preorder_partial_batches h cross join lateral jsonb_array_elements(h.items) y
       where h.preorder_id=p_id and h.status='completed' and (y->>'index')::int=ix;
     if q>coalesce((w.request_items->ix->>'quantity')::integer,0)-used_qty
       then raise exception 'Kitob miqdori oldingi topshirish bilan mos emas'; end if;
     select * into b from public.books where id=bid for update;
     if not found or b.stock<q then raise exception 'Tanlangan kitob omborda yetarli emas'; end if;
     update public.books set stock=stock-q where id=bid;
     selected:=selected||jsonb_build_array(jsonb_build_object(
       'index',ix,'book_id',bid,'title',b.title,'requested_title',w.request_items->ix->>'book_title',
       'quantity',q,'unit_price',price,'unit_cost',coalesce(b.cost_price,0),
       'book_image_path',w.request_items->ix->>'book_image_path'));
     sum_total:=sum_total+q::bigint*price;
   end loop;
   -- Single permitted settlement policy; the full remaining advance applies.
   insert into private.web_preorder_partial_batches(preorder_id,items,subtotal,choice)
   values(p_id,selected,sum_total,'all');
   select left(string_agg(x->>'requested_title', ', '),600)
     into notice from jsonb_array_elements(selected) x;
   notice:='Quyidagi kitoblaringiz topildi: '||coalesce(notice,'')||
     '. To‘langan avansingizning hali ishlatilmagan qismi TO‘LIQ '||
     'shu topilgan kitoblar va pochta haqidan ayriladi. '||
     'Qolgan to‘lov va manzilni Oldindan zakaslarim bo‘limida tasdiqlang. '||
     'Qolgan kitoblarni keyinchalik yana oldindan buyurtma berib '||
     'olib kelishingiz mumkin.';
   -- Advance the event version without changing the booking status.
   update public.web_preorder_requests
      set status_version=status_version+1,updated_at=now()
      where id=p_id returning status_version into evt_version;
   insert into private.web_preorder_events(preorder_id,version,audience,status,title,body)
      values(p_id,evt_version,'customer','partial_arrived',
        'Buyurtmangizdagi kitoblar keldi 📚',notice) returning id into evt;
   insert into public.customer_push_messages(id,phone,title,body,kind,sent_at)
      values(evt,w.phone,'Buyurtmangizdagi kitoblar keldi 📚',notice,'preorder_partial_arrived',now());
   perform private.web_preorder_retry();

 elsif p_action='missing' then
   -- This is deliberately a status notification, NOT a stock/payment mutation.
   -- The admin must have first recorded the received items.
   if not exists(select 1 from private.web_preorder_partial_batches
      where preorder_id=p_id and status in
        ('prepared','awaiting_payment','proof_submitted','completed')) then
     raise exception 'Avval kelgan kitoblarni yuboring';
   end if;
   if jsonb_typeof(p_payload->'indices')<>'array'
      or jsonb_array_length(p_payload->'indices') not between 1 and 50 then
     raise exception 'Kelmagan kitoblarni tanlang';
   end if;
   sum_total:=0;
   notice:='';
   for x in select value from jsonb_array_elements(p_payload->'indices') loop
     if jsonb_typeof(x)<>'number' then raise exception 'Kitob indeksi noto‘g‘ri'; end if;
     ix:=(x::text)::integer;
     if ix<0 or ix>=jsonb_array_length(w.request_items) then
        raise exception 'Kitob topilmadi';
     end if;
     select coalesce(sum((y->>'quantity')::integer),0) into used_qty
       from private.web_preorder_partial_batches h
       cross join lateral jsonb_array_elements(h.items) y
       where h.preorder_id=p_id and h.status<>'cancelled'
         and (y->>'index')::integer=ix;
     price:=greatest(coalesce((w.request_items->ix->>'quantity')::integer,0)-used_qty,0);
     if price<1 then raise exception 'Bu kitob kelganlar orasida yoki allaqachon belgilangan'; end if;
     insert into private.web_preorder_missing_marks(preorder_id,item_index,quantity)
       values(p_id,ix,price) on conflict(preorder_id,item_index) do nothing;
     get diagnostics q=row_count;
     if q>0 then
       sum_total:=sum_total+1;
       notice:=concat_ws(', ',nullif(notice,''),left(coalesce(w.request_items->ix->>'book_title','Kitob'),150));
     end if;
   end loop;
   if sum_total=0 then raise exception 'Bu kitoblar haqida oldin xabar yuborilgan'; end if;
   notice:='Quyidagi kitoblaringiz hozircha kelmadi: '||notice||
     '. Bu kitoblar kelgan kitoblar to‘loviga qo‘shilmagan. '||
     'Oldindan to‘langan avansning ishlatilmagan qismi to‘liq kelgan kitoblarga hisoblanadi. '||
     'Kelmagan kitoblarni keyinchalik qayta oldindan buyurtma qilishingiz mumkin.';
   update public.web_preorder_requests
      set status_version=status_version+1,updated_at=now()
      where id=p_id returning status_version into evt_version;
   insert into private.web_preorder_events(preorder_id,version,audience,status,title,body)
      values(p_id,evt_version,'customer','partial_missing',
        'Ayrim buyurtma kitoblaringiz kelmadi',notice) returning id into evt;
   insert into public.customer_push_messages(id,phone,title,body,kind,sent_at)
      values(evt,w.phone,'Ayrim buyurtma kitoblaringiz kelmadi',
         notice,'preorder_partial_missing',now());
   perform private.web_preorder_retry();
 elsif p_action='cancel_prepare' then
   -- Do not silently undo an arrival after an explicit missing notice.
   if exists(select 1 from private.web_preorder_missing_marks
       where preorder_id=p_id) then
     raise exception 'Kelmagan kitoblar haqida xabar yuborilgan. Bu bosqichni avtomatik bekor qilish mumkin emas';
   end if;
   select * into old from private.web_preorder_partial_batches
     where preorder_id=p_id and status='prepared' order by created_at desc limit 1 for update;
   if not found then raise exception 'Bekor qilish mumkin bo‘lgan tayyorlash yo‘q'; end if;
   for x in select value from jsonb_array_elements(old.items) loop
     update public.books set stock=stock+(x->>'quantity')::integer where id=(x->>'book_id')::uuid;
   end loop;
   update private.web_preorder_partial_batches set status='cancelled',updated_at=now() where id=old.id;
 elsif p_action='confirm' then
   select * into old from private.web_preorder_partial_batches
     where preorder_id=p_id and status in ('awaiting_payment','proof_submitted')
     order by created_at desc limit 1 for update;
   if not found then raise exception 'Tasdiqlanadigan hisob yo‘q'; end if;
   if old.amount_due>0 and old.status<>'proof_submitted' then raise exception 'Mijoz qolgan to‘lov chekini yubormagan'; end if;
   if old.recipient_name='' or old.recipient_phone='' or old.delivery_address='' then raise exception 'Mijoz yetkazish ma’lumotlarini to‘ldirsin'; end if;
   -- A unique technical invoice for EACH partial wave uses the existing
   -- verified-conversion path; the original deposit ledger stays unchanged.
   oid:=gen_random_uuid();
   update private.web_preorder_partial_batches set order_id=oid where id=old.id;
   insert into private.release_preorder_invoices
     (source,reference,deposit_credit,price_ready,payment_state,shipping_fee,base_total,amount_due,refund_due,
      submitted_amount,balance_paid,balance_proof_path,recipient_name,recipient_phone,
      delivery_address,delivery_type,delivery_saved,converted_order_id)
   values('web',old.id::text,old.deposit_applied,true,'verified',old.shipping_fee,old.subtotal,0,
      old.refund_due,old.amount_due,old.amount_due,old.proof_path,old.recipient_name,old.recipient_phone,
      old.delivery_address,old.delivery_type,true,oid)
   on conflict (source,reference) do update set
      deposit_credit=excluded.deposit_credit,
      price_ready=true,payment_state='verified',
      shipping_fee=excluded.shipping_fee,
      base_total=excluded.base_total,extra_total=0,
      amount_due=0,refund_due=excluded.refund_due,
      submitted_amount=excluded.submitted_amount,
      balance_paid=excluded.balance_paid,
      balance_proof_path=excluded.balance_proof_path,
      recipient_name=excluded.recipient_name,
      recipient_phone=excluded.recipient_phone,
      delivery_address=excluded.delivery_address,
      delivery_type=excluded.delivery_type,
      delivery_saved=true,
      converted_order_id=excluded.converted_order_id,
      revision=private.release_preorder_invoices.revision+1,
      updated_at=now();
   select jsonb_agg(jsonb_build_object('book_id',x->>'book_id','title',x->>'title',
     'quantity',(x->>'quantity')::integer,'price',(x->>'unit_price')::integer,
     'unit_price',(x->>'unit_price')::integer,'unit_cost',(x->>'unit_cost')::integer,
     'line_total',(x->>'quantity')::bigint*(x->>'unit_price')::bigint))
   into receipt_items from jsonb_array_elements(old.items) x;
   insert into private.release_conversion_orders(order_id,source,reference,items,subtotal,delivery_fee)
   values(oid,'web',old.id::text,receipt_items,old.subtotal::integer,old.shipping_fee);
   insert into public.orders(id,customer_name,phone,address,delivery_type,delivery_fee,
       subtotal,total,status,source,items,stock_reserved,payment_proof_path,payment_submitted_at,
       order_note,entered_by_admin,payment_status)
   values(oid,old.recipient_name,old.recipient_phone,old.delivery_address,old.delivery_type,
      old.shipping_fee,old.subtotal::integer,(old.subtotal+old.shipping_fee)::integer,'new',
      'app',receipt_items,true,old.proof_path,now(),
      'Qisman oldindan zakas '||p_id::text||'; avans '||old.deposit_applied::text,false,'paid');
   insert into private.release_order_owners(order_id,phone_key)
       values(oid,public._customer_phone_key(w.phone)) on conflict do nothing;
   perform public.admin_accept_order_with_note(p_secret,oid,'Qisman oldindan buyurtma');
   update private.web_preorder_partial_batches set status='completed',updated_at=now() where id=old.id;
   if old.choice='all' then
      update public.web_preorder_requests set status='arrived',updated_at=now(),status_version=status_version+1 where id=p_id;
   end if;
   insert into public.customer_push_messages(phone,title,body,kind)
   values(w.phone,'Kelgan kitoblaringiz tasdiqlandi 📦',
    'Qisman buyurtmangiz to‘lovi tekshirildi va jo‘natishga tayyorlanmoqda.','preorder_balance');
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.web_preorder_partial_detail(p_id);
end $function$;


-- The existing admin gateway accepts the separate missing action.
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
 if p_source='web' and p_action in
    ('partial_detail','partial_prepare','partial_cancel_prepare','partial_confirm','partial_missing') then
   return public.admin_web_preorder_partial(p_secret,p_id::uuid,
     substring(p_action from 9),p_payload);
 end if;
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
 elsif p_action='shipped' then
  -- This action is only available after the completed balance payment
  -- is atomically converted to a regular order. No price/stock edit.
  if inv.converted_order_id is null or inv.payment_state<>'verified' then
    raise exception 'Avval to‘lovni tasdiqlang va buyurtmaga o‘tkazing';
  end if;
  if r->>'status'='fulfilled' then
    return private.release_preorder_detail(p_source,p_id);
  end if;
  if r->>'status'<>'arrived' then
    raise exception 'Faqat kelgan oldindan buyurtma yuboriladi';
  end if;
  -- Reuse the existing shipping transition: correct stock/push semantics.
  perform public._order_set_status_core(inv.converted_order_id,'shipping');
  if p_source='native' then
    update public.preorders set status='fulfilled'
    where id=p_id::bigint and status='arrived';
  else
    update public.web_preorder_requests
      set status='fulfilled',updated_at=now(),status_version=status_version+1
    where id=p_id::uuid and status='arrived';
  end if;
  if not found then raise exception 'Oldindan zakas o‘zgargan. Yangilang'; end if;
  update private.release_preorder_invoices
    set revision=revision+1,updated_at=now()
    where source=p_source and reference=p_id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.release_preorder_detail(p_source,p_id);
end $function$;


-- Read-only customer/admin detail includes separately notified missing books.
CREATE OR REPLACE FUNCTION private.web_preorder_partial_detail(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare w public.web_preorder_requests%rowtype; batches jsonb; pending jsonb;
 credit bigint; used_credit bigint; closed boolean; item jsonb; i integer; used_qty integer; missing jsonb;
begin
 select * into w from public.web_preorder_requests where id=p_id;
 if not found then raise exception 'Zakas topilmadi'; end if;
 select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at,b.id),'[]'::jsonb),
        coalesce(sum(b.deposit_applied) filter(where b.status in ('awaiting_payment','proof_submitted','completed')),0),
        coalesce(bool_or(b.status='completed' and b.choice='all'),false)
 into batches,used_credit,closed from private.web_preorder_partial_batches b where b.preorder_id=p_id;
 credit:=greatest(w.deposit_amount::bigint-used_credit,0);
 pending:='[]'::jsonb;
 for i in 0..jsonb_array_length(w.request_items)-1 loop
  item:=w.request_items->i;
  select coalesce(sum((x->>'quantity')::integer),0) into used_qty
  from private.web_preorder_partial_batches b
  cross join lateral jsonb_array_elements(b.items) x
  where b.preorder_id=p_id and b.status in ('prepared','awaiting_payment','proof_submitted','completed')
    and (x->>'index')::integer=i;
  pending:=pending||jsonb_build_array(item||jsonb_build_object(
    'index',i,'remaining_quantity',case when closed then 0 else greatest((item->>'quantity')::integer-used_qty,0) end));
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object(
       'index',m.item_index,'quantity',m.quantity,
       'book_title',w.request_items->m.item_index->>'book_title') order by m.item_index),
       '[]'::jsonb) into missing
 from private.web_preorder_missing_marks m where m.preorder_id=p_id;
 return jsonb_build_object('id',w.id,'customer_name',w.customer_name,'phone',w.phone,
 'deposit_amount',w.deposit_amount,'deposit_per_book',w.deposit_per_book,
 'status',w.status,'original_items',w.request_items,'items',pending,'batches',batches,'missing_items',missing,
 'deposit_remaining',credit,'closed',closed);
end $function$;


-- Preserve detailed arrival/missing descriptions in the customer in-app inbox.
CREATE OR REPLACE FUNCTION public.customer_preorder_activity_list(p_install_id text, p_name text DEFAULT ''::text, p_phone text DEFAULT ''::text, p_limit integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id text:=trim(coalesce(p_install_id,'')); v_rows jsonb;
begin
 if length(v_id) not between 12 and 120 or
   coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
 into v_rows from (
  select 'native:'||e.id::text id,'native'::text source,p.id::text preorder_id,
   e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=v_id
    and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
    and not exists(
    select 1 from private.admin_preorder_hidden a
    where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web:'||e.id::text,'web'::text,w.id::text,
   e.status,case when e.status in ('partial_arrived','partial_missing') then e.title
       else case e.status when 'accepted' then 'Zakazingiz qabul qilindi ✅'
         when 'arrived' then 'Kitobingiz keldi 📚'
         else 'Oldindan zakaz holati o‘zgardi' end end,
   case when e.status in ('partial_arrived','partial_missing') then e.body
     else 'Oldindan zakazlarim bo‘limini tekshiring.'::text end,e.created_at
   from private.web_preorder_events e
   join public.web_preorder_requests w on w.id=e.preorder_id
   where e.audience='customer' and w.install_id=v_id
     and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
  order by created_at desc,id desc limit p_limit
 ) v;
 return v_rows;
end;
$function$

