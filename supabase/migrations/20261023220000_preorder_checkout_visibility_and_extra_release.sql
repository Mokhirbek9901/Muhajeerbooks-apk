-- Include catalog book identity for checkout add-ons; show balance proof to admins.
-- Removing extras stays possible even if a title is subsequently deactivated.
CREATE OR REPLACE FUNCTION public.customer_preorder_balance_list(p_install_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 then raise exception 'Qurilma ID noto‘g‘ri'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    into v_rows from (
      select p.id,p.book_id,p.status,p.quantity,p.deposit_amount,p.created_at,
        coalesce(b.title,'Kitob') title,coalesce(b.image_url,'') image_url,
        coalesce(h.quantity,0) reserved_quantity,
        case when r.preorder_id is not null then
          jsonb_build_object('base_total',r.base_total,
            'extra_total',r.extra_total,'deposit_credit',r.deposit_credit,
            'amount_due',r.amount_due,'unit_price',r.unit_price,
            'shipping_fee',r.shipping_fee,'admin_note',r.admin_note,
            'payment_state',r.payment_state,
            'extras',coalesce((select jsonb_agg(
              jsonb_build_object('book_id',ex.book_id,'title',bx.title,
                'quantity',ex.quantity,'unit_price',ex.unit_price)
              order by ex.created_at,ex.book_id)
             from private.preorder_extra_holds ex
             join public.books bx on bx.id=ex.book_id
             where ex.preorder_id=p.id),'[]'::jsonb))
          else null end as invoice
      from public.preorders p
      left join public.books b on b.id=p.book_id
      left join private.preorder_stock_holds h on h.preorder_id=p.id
      left join private.preorder_payment_requests r on r.preorder_id=p.id
      where p.install_id=trim(p_install_id)
       and not exists (select 1 from private.admin_preorder_hidden x
         where x.source='native' and x.order_id=p.id::text)
      order by p.created_at desc limit 60
    ) x;
  return v_rows;
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
        new_extras bigint; new_total bigint;
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
  new_total:=inv.base_total+new_extras;
  if new_total>100000000 then raise exception 'Jami summa limitdan yuqori'; end if;
  update private.preorder_payment_requests
    set extra_total=new_extras,amount_due=new_total-deposit_credit,
        updated_at=now()
    where preorder_id=v.id;
  return jsonb_build_object('quantity',new_qty,'extra_total',new_extras,
    'amount_due',new_total-inv.deposit_credit);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_preorders_all_list(p_secret text, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb; v_total integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_limit is null or p_limit not between 1 and 200
     or p_offset is null or p_offset<0 then
    raise exception 'Sahifalash noto‘g‘ri';
  end if;
  select count(*) into v_total from public.preorders p
    where not exists (select 1 from private.admin_preorder_hidden h
      where h.source='native' and h.order_id=p.id::text);
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id desc),'[]'::jsonb)
    into v_rows
  from (
    select p.id,p.book_id,b.title,b.price as catalog_price,b.stock as available_stock,
       p.customer_name,p.phone,p.quantity,p.status,p.deposit_amount,
       p.payment_proof_path,p.note,coalesce(b.preorder_arrival_note,'') arrival_note,
       p.created_at,coalesce(h.quantity,0) reserved_qty,
       r.unit_price,r.shipping_fee,r.base_total,r.extra_total,r.balance_proof_path,
       r.deposit_credit,r.amount_due,r.admin_note,r.payment_state
    from public.preorders p
    left join public.books b on b.id=p.book_id
    left join private.preorder_stock_holds h on h.preorder_id=p.id
    left join private.preorder_payment_requests r on r.preorder_id=p.id
    where not exists(select 1 from private.admin_preorder_hidden ar
      where ar.source='native' and ar.order_id=p.id::text)
    order by p.created_at desc,p.id desc
    limit p_limit offset p_offset
  ) x;
  return jsonb_build_object('rows',v_rows,'total',v_total);
end;
$function$;
