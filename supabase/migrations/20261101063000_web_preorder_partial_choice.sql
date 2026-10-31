-- Additive multi-title partial fulfilment. Existing preorders, balances and checkout untouched.
create table if not exists private.web_preorder_partial_batches (
 id uuid primary key default gen_random_uuid(),
 preorder_id uuid not null references public.web_preorder_requests(id),
 status text not null default 'prepared' check (status in ('prepared','awaiting_payment','proof_submitted','completed','cancelled')),
 items jsonb not null check (jsonb_typeof(items)='array'),
 choice text check (choice in ('all','keep')),
 subtotal bigint not null check(subtotal>=0),
 deposit_applied bigint not null default 0 check(deposit_applied>=0),
 shipping_fee integer not null default 0 check(shipping_fee in (0,4000)),
 amount_due bigint not null default 0 check(amount_due>=0),
 refund_due bigint not null default 0 check(refund_due>=0),
 recipient_name text not null default '',
 recipient_phone text not null default '',
 delivery_type text not null default '택배',
 delivery_address text not null default '',
 proof_path text not null default '',
 order_id uuid unique,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index if not exists web_preorder_partial_one_active
 on private.web_preorder_partial_batches(preorder_id)
 where status in ('prepared','awaiting_payment','proof_submitted');
create unique index if not exists web_preorder_partial_unique_receipt
 on private.web_preorder_partial_batches(proof_path) where proof_path<>'';
create index if not exists web_preorder_partial_history_idx
 on private.web_preorder_partial_batches(preorder_id,created_at desc);
alter table private.web_preorder_partial_batches enable row level security;
revoke all on private.web_preorder_partial_batches from public,anon,authenticated;

create or replace function private.web_preorder_partial_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.web_preorder_requests%rowtype; batches jsonb; pending jsonb;
 credit bigint; used_credit bigint; closed boolean; item jsonb; i integer; used_qty integer;
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
 return jsonb_build_object('id',w.id,'customer_name',w.customer_name,'phone',w.phone,
 'deposit_amount',w.deposit_amount,'deposit_per_book',w.deposit_per_book,
 'status',w.status,'original_items',w.request_items,'items',pending,'batches',batches,
 'deposit_remaining',credit,'closed',closed);
end $$;
revoke all on function private.web_preorder_partial_detail(uuid) from public,anon,authenticated;

create or replace function public.admin_web_preorder_partial(
 p_secret text,p_id uuid,p_action text default 'detail',p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.web_preorder_requests%rowtype; old private.web_preorder_partial_batches%rowtype;
 x jsonb; line jsonb; selected jsonb:='[]'::jsonb; b public.books%rowtype;
 ix integer; q integer; price integer; used_qty integer; sum_total bigint:=0;
 bid uuid; receipt_items jsonb; oid uuid; order_total bigint; total_qty integer;
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
   insert into private.web_preorder_partial_batches(preorder_id,items,subtotal)
   values(p_id,selected,sum_total);
   insert into public.customer_push_messages(phone,title,body,kind)
   values(w.phone,'Buyurtmangizdagi kitoblar keldi 📚',
    'Kelgan kitoblar va avansingizni qanday ishlatishni Oldindan zakazlarim bo‘limida tanlang.','preorder_balance');
 elsif p_action='cancel_prepare' then
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
      old.delivery_address,old.delivery_type,true,oid);
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
end $$;
revoke all on function public.admin_web_preorder_partial(text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.admin_web_preorder_partial(text,uuid,text,jsonb) to anon,authenticated,service_role;

create or replace function public.customer_web_preorder_partial(
 p_session text,p_id uuid,p_action text default 'detail',p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.web_preorder_requests%rowtype; b private.web_preorder_partial_batches%rowtype;
 choice_value text; used_credit bigint; alloc bigint; count_selected integer; total_units integer;
 ship integer; dtype text; nm text; digits text; addr text; path text; blocked boolean;
begin
 perform private.release_assert_owner(p_session,'web',p_id::text);
 perform pg_advisory_xact_lock(hashtextextended('partial:'||p_id::text,28));
 select * into w from public.web_preorder_requests where id=p_id for update;
 if p_action='detail' then return private.web_preorder_partial_detail(p_id); end if;
 select * into b from private.web_preorder_partial_batches
 where preorder_id=p_id and status in ('prepared','awaiting_payment','proof_submitted')
 order by created_at desc limit 1 for update;
 if not found then raise exception 'Kutilayotgan qisman hisob topilmadi'; end if;
 if p_action='choose' then
   if b.status<>'prepared' then raise exception 'Avans tanlovi allaqachon saqlangan'; end if;
   choice_value:=p_payload->>'choice';
   if choice_value not in ('all','keep') then raise exception 'Avans taqsimotini tanlang'; end if;
   nm:=trim(coalesce(p_payload->>'recipient_name',''));
   digits:=regexp_replace(coalesce(p_payload->>'recipient_phone',''),'[^0-9]','','g');
   addr:=trim(coalesce(p_payload->>'address',''));
   dtype:=p_payload->>'delivery_type';
   if length(nm) not between 2 and 80 or digits !~ '^010[0-9]{8}$'
      or dtype not in ('택배','경산 직접수령','경산 무료배송')
      or length(addr)>500 or (dtype<>'경산 직접수령' and length(addr)<8)
      then raise exception 'Ism, telefon va manzilni tekshiring'; end if;
   if dtype='경산 무료배송' and addr !~ '경산' and lower(addr) !~ 'gyeongsan'
      then raise exception 'Gyeongsan manzilini kiriting'; end if;
   select coalesce(sum(deposit_applied),0) into used_credit
   from private.web_preorder_partial_batches where preorder_id=p_id and status='completed';
   select coalesce(sum((x->>'quantity')::int),0) into count_selected from jsonb_array_elements(b.items) x;
   select coalesce(sum((x->>'quantity')::int),0) into total_units from jsonb_array_elements(w.request_items) x;
   if choice_value='keep' and count_selected>=total_units-
      (select coalesce(sum((x->>'quantity')::int),0) from private.web_preorder_partial_batches h
        cross join lateral jsonb_array_elements(h.items) x
        where h.preorder_id=p_id and h.status='completed') then
        raise exception 'Qolgan kitob yo‘q. Barcha avansni ishlating'; end if;
   alloc:=case when choice_value='all' then greatest(w.deposit_amount::bigint-used_credit,0)
     else least(greatest(w.deposit_amount::bigint-used_credit,0),
         count_selected::bigint*w.deposit_per_book::bigint) end;
   select exists(select 1 from jsonb_array_elements(b.items) x
     join public.books k on k.id=(x->>'book_id')::uuid
     where k.discount_percent>0 and (k.discount_ends_at is null or k.discount_ends_at>now())
       and k.discount_free_delivery=false) into blocked;
   ship:=case when dtype in ('경산 직접수령','경산 무료배송') or (count_selected>=4 and not blocked)
     then 0 else 4000 end;
   update private.web_preorder_partial_batches set
     status='awaiting_payment',choice=choice_value,deposit_applied=alloc,shipping_fee=ship,
     amount_due=greatest(b.subtotal+ship-alloc,0),
     refund_due=greatest(alloc-b.subtotal-ship,0),
     recipient_name=nm,recipient_phone=digits,delivery_type=dtype,
     delivery_address=case when dtype='경산 직접수령' then dtype else addr end,
     updated_at=now() where id=b.id;
 elsif p_action='proof' then
   if b.status='proof_submitted' and b.proof_path=p_payload->>'path'
     then return private.web_preorder_partial_detail(p_id); end if;
   if b.status<>'awaiting_payment' or b.amount_due<=0 then raise exception 'To‘lov kerak emas yoki tanlov tasdiqlanmagan'; end if;
   path:=trim(coalesce(p_payload->>'path',''));
   if path !~ '^receipts/[A-Za-z0-9._/-]+$'
     or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=path)
     or not exists(select 1 from private.release_receipt_claims c
           where c.path=path and c.phone_key=public._customer_phone_key(w.phone))
     or exists(select 1 from public.orders where payment_proof_path=path)
     or exists(select 1 from private.release_preorder_invoices where balance_proof_path=path)
     then raise exception 'Chek topilmadi yoki avval ishlatilgan'; end if;
   update private.web_preorder_partial_batches
      set status='proof_submitted',proof_path=path,updated_at=now() where id=b.id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.web_preorder_partial_detail(p_id);
end $$;
revoke all on function public.customer_web_preorder_partial(text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.customer_web_preorder_partial(text,uuid,text,jsonb) to anon,authenticated,service_role;
