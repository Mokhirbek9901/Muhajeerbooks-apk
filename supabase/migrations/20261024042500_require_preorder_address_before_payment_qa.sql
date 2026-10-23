-- QA hardening: server must enforce address/recipient entry even if
-- a stale app bypasses the current checkout form. All old invoices and
-- uploaded payment receipts remain untouched.
CREATE OR REPLACE FUNCTION public.customer_web_preorder_checkout(p_session text, p_preorder_id uuid, p_action text DEFAULT 'detail'::text, p_book_id uuid DEFAULT NULL::uuid, p_delta integer DEFAULT 0, p_path text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  k text:=private.pin_session_phone(p_session);
  v public.web_preorder_requests%rowtype;
  inv private.web_preorder_checkout%rowtype;
  b public.books%rowtype;
  old_qty integer:=0; old_unit integer:=0; next_qty integer;
  extra_qty integer; extra_sum bigint; ship integer; main_total bigint;
  detail jsonb; has_multiple boolean;
begin
  if k is null then raise exception 'PIN bilan qayta kiring'; end if;
  if p_preorder_id is null or p_action not in ('detail','add','proof')
    then raise exception 'Zakaz yoki amal noto‘g‘ri'; end if;
  select * into v from public.web_preorder_requests where id=p_preorder_id for update;
  if not found or public._customer_phone_key(v.phone)<>k or
    exists(select 1 from private.admin_preorder_hidden h
      where h.source='web' and h.order_id=v.id::text) or not (
      exists(select 1 from private.customer_pin_devices d
        where d.phone_key=k and d.install_id=v.install_id and v.install_id is not null)
      or (v.install_id is null and exists(
        select 1 from private.customer_pin_profiles profile
        where profile.phone_key=k and
          lower(regexp_replace(trim(profile.full_name),'\s+',' ','g'))=
          lower(regexp_replace(trim(v.customer_name),'\s+',' ','g'))
      ))
    ) then raise exception 'Bu zakaz profilingizga tegishli emas'; end if;

  has_multiple:=case when jsonb_typeof(v.request_items)='array'
    then jsonb_array_length(v.request_items)>1 else false end;
  select * into inv from private.web_preorder_checkout where preorder_id=v.id for update;
  -- A multi-title legacy request has no reliable price for each title;
  -- do not fabricate a final invoice until admin confirms its total.
  if not found and v.status='arrived' and v.book_id is not null
      and not has_multiple then
    select * into b from public.books where id=v.book_id;
    if found and b.price>0 and v.quantity between 1 and 20 then
      ship:=case when v.quantity>=4 and not exists(
        select 1 from public.books promo where promo.discount_percent>0
          and (promo.discount_ends_at is null or promo.discount_ends_at>now())
          and promo.discount_free_delivery=false
      ) then 0 else 4000 end;
      main_total:=v.quantity::bigint*b.price+ship;
      insert into private.web_preorder_checkout
        (preorder_id,unit_price,shipping_fee,base_total,deposit_credit,amount_due)
      values(v.id,b.price,ship,main_total,
        greatest(coalesce(v.deposit_amount,0),0),
        greatest(main_total-greatest(coalesce(v.deposit_amount,0),0),0))
      on conflict(preorder_id) do nothing;
      select * into inv from private.web_preorder_checkout where preorder_id=v.id for update;
    end if;
  end if;

  if p_action='add' then
    if inv.preorder_id is null or v.status<>'arrived' or inv.payment_state<>'requested'
      then raise exception 'Savat yopiq yoki narx hali belgilanmagan'; end if;
    if p_book_id is null or p_book_id=v.book_id or p_delta=0 or abs(p_delta)>5
      then raise exception 'Kitob yoki miqdor noto‘g‘ri'; end if;
    select * into b from public.books where id=p_book_id for update;
    if not found then raise exception 'Kitob mavjud emas'; end if;
    select quantity,unit_price into old_qty,old_unit
      from private.web_preorder_checkout_items
      where preorder_id=v.id and book_id=p_book_id for update;
    old_qty:=coalesce(old_qty,0); next_qty:=old_qty+p_delta;
    if next_qty<0 or next_qty>10 or (p_delta>0 and
        (not b.is_active or b.price<=0 or b.stock<p_delta)) then
      raise exception 'Kitob yoki ombor miqdorini tekshiring'; end if;
    if p_delta<0 and old_qty< -p_delta then
      raise exception 'Olib tashlash uchun kitob yo‘q'; end if;
    if next_qty=0 then
      delete from private.web_preorder_checkout_items
        where preorder_id=v.id and book_id=p_book_id;
    else
      insert into private.web_preorder_checkout_items(preorder_id,book_id,quantity,unit_price)
      values(v.id,p_book_id,next_qty,coalesce(nullif(old_unit,0),b.price))
      on conflict(preorder_id,book_id) do update set quantity=excluded.quantity;
    end if;
    update public.books set stock=stock-p_delta where id=p_book_id;
    select coalesce(sum(quantity),0),coalesce(sum(quantity::bigint*unit_price),0)
      into extra_qty,extra_sum from private.web_preorder_checkout_items
      where preorder_id=v.id;
    -- Delivery is selected in the same checkout as ordinary orders.
    -- Recalculate after every add/remove; never rely on stale old shipping_fee.
    ship:=case when inv.delivery_type in ('경산 직접수령','경산 무료배송') then 0
      when v.quantity+extra_qty>=4 and not exists(
        select 1 from public.books promo where promo.discount_percent>0
          and (promo.discount_ends_at is null or promo.discount_ends_at>now())
          and promo.discount_free_delivery=false
      ) then 0 else 4000 end;
    main_total:=v.quantity::bigint*inv.unit_price+ship;
    if main_total+extra_sum>100000000 then raise exception 'Summa limitdan katta'; end if;
    update private.web_preorder_checkout
      set base_total=main_total,extra_total=extra_sum,
        shipping_fee=ship,
        amount_due=greatest(main_total+extra_sum-deposit_credit,0),
        updated_at=now()
      where preorder_id=v.id;
  elsif p_action='proof' then
    if inv.preorder_id is null or v.status<>'arrived' or
       inv.payment_state<>'requested' or inv.amount_due<=0 or
       inv.delivery_saved is not true or
       length(trim(coalesce(p_path,''))) not between 3 and 500 then
      raise exception 'Qolgan to‘lov cheki qabul qilinmaydi'; end if;
    update private.web_preorder_checkout
      set payment_state='proof_submitted',balance_proof_path=trim(p_path),
        proof_submitted_amount=inv.amount_due, shipping_refund_due=0,
        updated_at=now() where preorder_id=v.id;
    update public.web_preorder_requests
      set status_note='Qolgan to‘lov cheki yuborildi — admin tekshirsin',
        status_version=coalesce(status_version,0)+1,updated_at=now()
      where id=v.id;
  end if;

  select * into inv from private.web_preorder_checkout where preorder_id=v.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'book_id',e.book_id,'title',extra_book.title,'quantity',e.quantity,
    'unit_price',e.unit_price) order by e.created_at,e.book_id),'[]'::jsonb)
    into detail from private.web_preorder_checkout_items e
      join public.books extra_book on extra_book.id=e.book_id where e.preorder_id=v.id;
  return jsonb_build_object(
    'source','web','id',v.id,'title',v.book_title,'book_id',v.book_id,
    'quantity',v.quantity,'status',v.status,
    'deposit_credit',greatest(coalesce(v.deposit_amount,0),0),
    'price_ready',inv.preorder_id is not null,'unit_price',inv.unit_price,
    'shipping_fee',case when inv.preorder_id is null then null
      else inv.base_total-(v.quantity::bigint*inv.unit_price) end,
    'base_total',inv.base_total,'extra_total',inv.extra_total,
    'amount_due',inv.amount_due,'payment_state',inv.payment_state,
    'proof_submitted_amount',inv.proof_submitted_amount,
    'shipping_refund_due',inv.shipping_refund_due,
    'extras',detail,
    'can_edit',v.status='arrived' and inv.payment_state='requested',
    'recipient_name',coalesce(nullif(inv.recipient_name,''),v.customer_name),
    'recipient_phone',coalesce(nullif(inv.recipient_phone,''),v.phone),
    'delivery_address',inv.delivery_address,
    'delivery_type',coalesce(nullif(inv.delivery_type,''),'택배'),
    'delivery_saved',coalesce(inv.delivery_saved,false),
    'note',case when inv.preorder_id is null
      then 'Yakuniy narxni admin tasdiqlashi kerak'
      else 'Joriy katalog narxi asosida hisoblangan; admin tekshiradi' end);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_web_preorder_checkout_confirm(p_secret text, p_preorder_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.web_preorder_requests%rowtype; inv private.web_preorder_checkout%rowtype;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Admin ruxsati yo‘q'; end if;
 select * into v from public.web_preorder_requests where id=p_preorder_id for update;
 if not found or v.status<>'arrived' then raise exception 'Zakaz topilmadi yoki kelmagan'; end if;
 select * into inv from private.web_preorder_checkout where preorder_id=v.id for update;
 if not found then raise exception 'To‘lov hisobi mavjud emas'; end if;
 if inv.payment_state='verified' then
   return jsonb_build_object('payment_state','verified','duplicate',true); end if;
 if inv.delivery_saved is not true then
   raise exception 'Qabul qiluvchi, manzil va yetkazish turi hali kiritilmagan';
 end if;
 if inv.amount_due>0 and (inv.payment_state<>'proof_submitted' or inv.balance_proof_path='') then
   raise exception 'Qolgan to‘lov cheki kelmagan'; end if;
 update private.web_preorder_checkout
   set payment_state='verified',updated_at=now() where preorder_id=v.id;
 update public.web_preorder_requests
   set status_note='Qolgan to‘lov tasdiqlandi',updated_at=now(),
     status_version=coalesce(status_version,0)+1 where id=v.id;
 if coalesce(trim(v.phone),'')<>'' then
   insert into public.customer_push_messages(phone,title,body,kind)
   values(v.phone,'Oldindan zakaz to‘lovi tasdiqlandi ✅',
     case when inv.shipping_refund_due>0 then
       'To‘lov qabul qilindi. Yetkazish uchun ortiqcha to‘lovni do‘kon qaytaradi.'
       else 'Qolgan to‘lov tasdiqlandi. Yetkazish bo‘yicha do‘kon xabar beradi.' end,
     'preorder_balance');
 end if;
 return jsonb_build_object('payment_state','verified','duplicate',false);
end;
$function$;

revoke all on function public.customer_web_preorder_checkout(text,uuid,text,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.customer_web_preorder_checkout(text,uuid,text,uuid,integer,text) to service_role;
revoke all on function public.admin_web_preorder_checkout_confirm(text,uuid) from public,anon,authenticated;
grant execute on function public.admin_web_preorder_checkout_confirm(text,uuid) to service_role;
