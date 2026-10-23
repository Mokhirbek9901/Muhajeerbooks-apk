-- Keep prepaid-book checkout consistent with normal 4+ free delivery rule,
-- except during active promotions that explicitly disable the benefit.
CREATE OR REPLACE FUNCTION public.admin_native_preorder_arrive_invoice(p_secret text, p_id bigint, p_expected_status text, p_unit_price integer, p_shipping_fee integer, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.preorders%rowtype; v_note text:=trim(coalesce(p_note,''));
        v_total bigint; v_due bigint; v_hold integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_id is null or coalesce(p_unit_price,0)<=0
     or coalesce(p_shipping_fee,-1) not between 0 and 100000
     or length(v_note) not between 3 and 500 then
    raise exception 'Narx, pochta va admin izohini tekshiring';
  end if;
  select * into v from public.preorders where id=p_id for update;
  if not found then raise exception 'Oldindan zakaz topilmadi'; end if;
  if v.status is distinct from p_expected_status or
     v.status not in ('accepted','contacted') then
    raise exception 'Zakaz oldin qabul qilinishi kerak. Ro‘yxatni yangilang';
  end if;
  if exists(select 1 from private.admin_preorder_hidden h
     where h.source='native' and h.order_id=p_id::text) then
    raise exception 'Arxivlangan zakaz';
  end if;
  update public.books set stock=stock where id=v.book_id;
  select quantity into v_hold from private.preorder_stock_holds
    where preorder_id=p_id;
  if v_hold is distinct from v.quantity then
    raise exception 'Bu zakaz uchun % ta kitob band qilinmagan. Kelgan partiya sonini oldin omborga qo‘shing',v.quantity;
  end if;
  v_total:=v.quantity::bigint*p_unit_price +
    (case when v.quantity>=4 and not exists(
      select 1 from public.books b where b.discount_percent>0
        and (b.discount_ends_at is null or b.discount_ends_at>now())
        and b.discount_free_delivery=false
    ) then 0 else p_shipping_fee end);
  if v_total>100000000 or v_total<v.deposit_amount then
    raise exception 'Yakuniy summa avansdan kam yoki juda katta. Hisobni tekshiring';
  end if;
  v_due:=v_total-v.deposit_amount;
  insert into private.preorder_payment_requests
    (preorder_id,unit_price,shipping_fee,base_total,extra_total,
     deposit_credit,amount_due,admin_note,payment_state,updated_at)
  values(p_id,p_unit_price,p_shipping_fee,v_total,0,
    v.deposit_amount,v_due,v_note,'requested',now())
  on conflict(preorder_id) do update set
    unit_price=excluded.unit_price,shipping_fee=excluded.shipping_fee,
    base_total=excluded.base_total,extra_total=0,
    deposit_credit=excluded.deposit_credit,amount_due=excluded.amount_due,
    admin_note=excluded.admin_note,payment_state='requested',
    balance_proof_path='',updated_at=now();
  update public.preorders set status='arrived' where id=p_id;
  insert into private.admin_preorder_status_events
    (preorder_id,old_status,new_status,admin_note)
    values(p_id,v.status,'arrived',v_note);
  -- Durable IN-APP notification; native push needs its separate live provider.
  if coalesce(trim(v.phone),'')<>'' then
    insert into public.customer_push_messages(phone,title,body,kind)
    values(v.phone,'Oldindan zakazingiz keldi 📚',
      'Kitobingiz keldi. Qolgan to‘lov va admin izohini ilovadagi Oldindan zakazlarim bo‘limida tekshiring.',
      'preorder_balance');
  end if;
  update private.preorder_payment_requests set last_notified_at=now()
   where preorder_id=p_id;
  return jsonb_build_object('status','arrived','quantity_reserved',v_hold,
    'total',v_total,'deposit_credit',v.deposit_amount,'amount_due',v_due);
end;
$function$;

CREATE OR REPLACE FUNCTION public.customer_preorder_extra_change(p_install_id text, p_preorder_id bigint, p_book_id uuid, p_delta integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.preorders%rowtype;
        inv private.preorder_payment_requests%rowtype;
        book public.books%rowtype;
        old_qty integer:=0; old_price integer:=0; new_qty integer;
        new_extras bigint; new_total bigint; v_extra_qty integer; v_shipping integer;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 or p_preorder_id is null
    or p_book_id is null or p_delta is null or p_delta=0 or abs(p_delta)>5 then
    raise exception 'Savatcha so‘rovi noto‘g‘ri';
  end if;
  select * into v from public.preorders
    where id=p_preorder_id and install_id=trim(p_install_id) for update;
  if not found or v.status<>'arrived' then
    raise exception 'Bu oldindan zakaz uchun savat yopiq';
  end if;
  select * into inv from private.preorder_payment_requests
    where preorder_id=v.id for update;
  if not found or inv.payment_state<>'requested' then
    raise exception 'To‘lov cheki yuborilgan yoki savat yopiq';
  end if;
  if v.book_id=p_book_id then
    raise exception 'Asosiy kitob allaqachon band qilingan';
  end if;
  select * into book from public.books where id=p_book_id for update;
  if not found or (p_delta>0 and (not book.is_active or book.price<=0)) then
    raise exception 'Kitob sotuvda mavjud emas';
  end if;
  select quantity,unit_price into old_qty,old_price
    from private.preorder_extra_holds
    where preorder_id=v.id and book_id=p_book_id for update;
  old_qty:=coalesce(old_qty,0);
  new_qty:=old_qty+p_delta;
  if new_qty<0 or new_qty>10 then
    raise exception 'Miqdor 0–10 orasida bo‘lishi kerak';
  end if;
  if p_delta>0 then
    if book.stock<p_delta then raise exception 'Omborda yetarli kitob qolmagan'; end if;
    update public.books set stock=stock-p_delta where id=p_book_id;
    insert into private.preorder_extra_holds(preorder_id,book_id,quantity,unit_price)
      values(v.id,p_book_id,new_qty,coalesce(nullif(old_price,0),book.price))
    on conflict(preorder_id,book_id) do update set quantity=excluded.quantity;
  elsif new_qty=0 then
    delete from private.preorder_extra_holds
      where preorder_id=v.id and book_id=p_book_id;
    update public.books set stock=stock-p_delta where id=p_book_id;
  else
    update private.preorder_extra_holds set quantity=new_qty
      where preorder_id=v.id and book_id=p_book_id;
    update public.books set stock=stock-p_delta where id=p_book_id;
  end if;
  select coalesce(sum(quantity::bigint*unit_price),0) into new_extras
    from private.preorder_extra_holds where preorder_id=v.id;
  select coalesce(sum(quantity),0) into v_extra_qty
    from private.preorder_extra_holds where preorder_id=v.id;
  v_shipping:=case when v.quantity+v_extra_qty>=4 and not exists(
    select 1 from public.books b
    where b.discount_percent>0
      and (b.discount_ends_at is null or b.discount_ends_at>now())
      and b.discount_free_delivery=false
  ) then 0 else inv.shipping_fee end;
  new_total:=(v.quantity::bigint*inv.unit_price)+v_shipping+new_extras;
  if new_total>100000000 then raise exception 'Jami summa limitdan yuqori'; end if;
  update private.preorder_payment_requests
    set base_total=(v.quantity::bigint*inv.unit_price)+v_shipping,
        extra_total=new_extras,amount_due=new_total-deposit_credit,
        updated_at=now()
    where preorder_id=v.id;
  return jsonb_build_object('quantity',new_qty,'extra_total',new_extras,
    'amount_due',new_total-inv.deposit_credit);
end;
$function$;
