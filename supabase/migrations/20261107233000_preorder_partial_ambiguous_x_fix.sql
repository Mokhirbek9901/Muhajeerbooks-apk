-- Fix 42702 "column reference x is ambiguous" in preorder partial prepare/confirm.
-- SQL table column aliases must not collide with plpgsql variable x.
-- Changes only alias references: all order, stock, deposit, notification and shipping logic is preserved.
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
 private_hold boolean; create_catalog boolean; new_title text;
 missing_count integer; missing_names text;
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
     price:=(x->>'unit_price')::integer;
     private_hold:=coalesce((x->>'private_preorder_stock')::boolean,false);
     create_catalog:=coalesce((x->>'create_catalog')::boolean,false);
     bid:=nullif(x->>'book_id','')::uuid;
     if ix is null or ix<0 or ix>=jsonb_array_length(w.request_items) or q not between 1 and 200 or price not between 1 and 10000000
       then raise exception 'Kitob soni yoki narxi noto‘g‘ri'; end if;
     if exists(select 1 from jsonb_array_elements(selected) y where (y->>'index')::integer=ix)
       then raise exception 'Bitta kitobni ikki marta belgilamang'; end if;
     select coalesce(sum((y->>'quantity')::int),0) into used_qty
       from private.web_preorder_partial_batches h cross join lateral jsonb_array_elements(h.items) y
       where h.preorder_id=p_id and h.status='completed' and (y->>'index')::int=ix;
     if q>coalesce((w.request_items->ix->>'quantity')::integer,0)-used_qty
       then raise exception 'Kitob miqdori oldingi topshirish bilan mos emas'; end if;
     if create_catalog then
       if not private_hold or bid is not null then
         raise exception 'Yangi katalog kitobi faqat shaxsiy buyurtma uchun yaratiladi';
       end if;
       new_title:=left(trim(coalesce(w.request_items->ix->>'book_title','')),180);
       if length(new_title)<2 then raise exception 'Kitob nomini tekshiring'; end if;
       perform pg_advisory_xact_lock(hashtextextended('preorder-private-catalog:'||lower(new_title),37));
       select * into b from public.books
         where lower(btrim(title))=lower(new_title)
         order by created_at,id limit 1 for update;
       if not found then
         insert into public.books(title,price,stock,is_active)
           values(new_title,price,0,true) returning * into b;
       end if;
       bid:=b.id;
     else
       select * into b from public.books where id=bid for update;
     end if;
     if b.id is null then raise exception 'Tanlangan kitob katalogda topilmadi'; end if;
     if not private_hold then
       if b.stock<q then raise exception 'Tanlangan kitob omborda yetarli emas'; end if;
       update public.books set stock=stock-q where id=bid;
     end if;
     selected:=selected||jsonb_build_array(jsonb_build_object(
       'index',ix,'book_id',bid,'title',b.title,'requested_title',w.request_items->ix->>'book_title',
       'quantity',q,'unit_price',price,'unit_cost',coalesce(b.cost_price,0),
       'private_preorder_stock',private_hold,
       'book_image_path',w.request_items->ix->>'book_image_path'));
     sum_total:=sum_total+q::bigint*price;
   end loop;
   -- Single permitted settlement policy; the full remaining advance applies.
   insert into private.web_preorder_partial_batches(preorder_id,items,subtotal,choice)
   values(p_id,selected,sum_total,'all');
   select left(string_agg(received_item.value->>'requested_title', ', '),600)
     into notice from jsonb_array_elements(selected) as received_item(value);
   notice:='Quyidagi kitoblaringiz keldi: '||coalesce(notice,'')||
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

   -- The same transaction sends a separate missing notice for the
   -- administrator's per-title Kelmadi selections. No second customer order.
   if p_payload ? 'missing_indices' then
     if jsonb_typeof(p_payload->'missing_indices')<>'array'
       or jsonb_array_length(p_payload->'missing_indices')>50
       then raise exception 'Kelmagan kitoblar ro‘yxati noto‘g‘ri'; end if;
     missing_count:=0; missing_names:='';
     for x in select value from jsonb_array_elements(p_payload->'missing_indices') loop
       if jsonb_typeof(x)<>'number' then raise exception 'Kelmadi kitobi indeksi noto‘g‘ri'; end if;
       ix:=(x::text)::integer;
       if ix<0 or ix>=jsonb_array_length(w.request_items) then
         raise exception 'Kelmagan kitob ro‘yxatda topilmadi'; end if;
       if exists(select 1 from jsonb_array_elements(selected) y
           where (y->>'index')::integer=ix) then
         raise exception 'Bitta kitob bir vaqtning o‘zida keldi va kelmadi bo‘lolmaydi';
       end if;
       select coalesce(sum((y->>'quantity')::integer),0) into used_qty
         from private.web_preorder_partial_batches h
         cross join lateral jsonb_array_elements(h.items) y
         where h.preorder_id=p_id and h.status<>'cancelled'
           and (y->>'index')::integer=ix;
       q:=greatest(coalesce((w.request_items->ix->>'quantity')::integer,0)-used_qty,0);
       if q<1 then raise exception 'Kelmagan kitobning qolgan soni noto‘g‘ri'; end if;
       insert into private.web_preorder_missing_marks(preorder_id,item_index,quantity)
         values(p_id,ix,q) on conflict(preorder_id,item_index) do nothing;
       get diagnostics price=row_count;
       if price<>1 then raise exception 'Bu kitobning kelmaganligi oldin bildirilgan'; end if;
       missing_count:=missing_count+1;
       missing_names:=concat_ws(', ',nullif(missing_names,''),
         left(coalesce(w.request_items->ix->>'book_title','Kitob'),150));
     end loop;
     if missing_count>0 then
       notice:='Quyidagi kitoblar hozircha kelmadi: '||missing_names||
         '. Ularning puli kelgan kitoblarga alohida qo‘shilmaydi. '||
         'Oldingi avansning ishlatilmagan qismi to‘liq kelgan kitoblarga hisoblanadi. '||
         'Bu kitoblarni keyin yangi oldindan buyurtmada qayta so‘rashingiz mumkin.';
       update public.web_preorder_requests
         set status_version=status_version+1,updated_at=now()
         where id=p_id returning status_version into evt_version;
       insert into private.web_preorder_events(preorder_id,version,audience,status,title,body)
         values(p_id,evt_version,'customer','partial_missing',
           'Ayrim kitoblaringiz kelmadi',notice) returning id into evt;
       insert into public.customer_push_messages(id,phone,title,body,kind,sent_at)
         values(evt,w.phone,'Ayrim kitoblaringiz kelmadi',notice,'preorder_partial_missing',now());
       perform private.web_preorder_retry();
     end if;
   end if;

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
     if not coalesce((x->>'private_preorder_stock')::boolean,false) then
       update public.books set stock=stock+(x->>'quantity')::integer
       where id=(x->>'book_id')::uuid;
     end if;
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
   select jsonb_agg(jsonb_build_object('book_id',receipt_item.value->>'book_id','title',receipt_item.value->>'title',
     'quantity',(receipt_item.value->>'quantity')::integer,'price',(receipt_item.value->>'unit_price')::integer,
     'unit_price',(receipt_item.value->>'unit_price')::integer,'unit_cost',(receipt_item.value->>'unit_cost')::integer,
     'line_total',(receipt_item.value->>'quantity')::bigint*(receipt_item.value->>'unit_price')::bigint,
     'preorder_private_stock',coalesce((receipt_item.value->>'private_preorder_stock')::boolean,false)))
   into receipt_items from jsonb_array_elements(old.items) as receipt_item(value);
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
end $function$

