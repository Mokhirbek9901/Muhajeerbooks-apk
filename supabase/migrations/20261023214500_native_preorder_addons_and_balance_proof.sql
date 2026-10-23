-- Preorder balance invoices: customer may add/remove EXTRA in-stock books.
-- Prices are snapshotted; all extra quantities are atomically subtracted from
-- available books.stock, independent of the original preorder stock hold.
create table if not exists private.preorder_extra_holds(
  preorder_id bigint not null references public.preorders(id) on delete restrict,
  book_id uuid not null references public.books(id) on delete restrict,
  quantity integer not null check(quantity between 1 and 10),
  unit_price integer not null check(unit_price>0),
  created_at timestamptz not null default now(),
  primary key(preorder_id,book_id)
);
revoke all on private.preorder_extra_holds from public,anon,authenticated;

-- Customer identity is tied to the high-entropy installation ID that
-- originated the original preorder, never to a bare phone number.
create or replace function public.customer_preorder_balance_list(
  p_install_id text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_rows jsonb;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 then raise exception 'Qurilma ID noto‘g‘ri'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    into v_rows from (
      select p.id,p.status,p.quantity,p.created_at,
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
$$;
revoke all on function public.customer_preorder_balance_list(text)
  from public,anon,authenticated;
grant execute on function public.customer_preorder_balance_list(text)
  to service_role;

create or replace function public.customer_preorder_extra_change(
  p_install_id text,p_preorder_id bigint,p_book_id uuid,p_delta integer
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.preorders%rowtype;
        inv private.preorder_payment_requests%rowtype;
        book public.books%rowtype;
        old_qty integer:=0; old_price integer:=0; new_qty integer;
        new_extras bigint; new_total bigint;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 or p_preorder_id is null
    or p_book_id is null or p_delta=0 or abs(p_delta)>5 then
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
  if not found or not book.is_active or book.price<=0 then
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
$$;
revoke all on function public.customer_preorder_extra_change(text,bigint,uuid,integer)
  from public,anon,authenticated;
grant execute on function public.customer_preorder_extra_change(text,bigint,uuid,integer)
  to service_role;

create or replace function public.customer_preorder_balance_proof(
  p_install_id text,p_preorder_id bigint,p_path text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.preorders%rowtype; r private.preorder_payment_requests%rowtype;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 or length(trim(coalesce(p_path,''))) not between 3 and 500 then
    raise exception 'To‘lov cheki noto‘g‘ri';
  end if;
  select * into v from public.preorders
    where id=p_preorder_id and install_id=trim(p_install_id) for update;
  if not found or v.status<>'arrived' then
    raise exception 'Bu zakaz to‘lov uchun tayyor emas';
  end if;
  select * into r from private.preorder_payment_requests
    where preorder_id=v.id for update;
  if not found or r.payment_state<>'requested' or r.amount_due<=0 then
    raise exception 'Qolgan to‘lov allaqachon yuborilgan yoki summa nol';
  end if;
  update private.preorder_payment_requests
    set payment_state='proof_submitted',balance_proof_path=trim(p_path),
        updated_at=now()
    where preorder_id=v.id;
  return jsonb_build_object('payment_state','proof_submitted','amount_due',r.amount_due);
end;
$$;
revoke all on function public.customer_preorder_balance_proof(text,bigint,text)
  from public,anon,authenticated;
grant execute on function public.customer_preorder_balance_proof(text,bigint,text)
  to service_role;

create or replace function public.admin_native_preorder_payment_confirm(
  p_secret text,p_preorder_id bigint
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare p public.preorders%rowtype;
        r private.preorder_payment_requests%rowtype;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q'; end if;
  select * into p from public.preorders where id=p_preorder_id for update;
  if not found or p.status<>'arrived' then raise exception 'Zakaz tayyor emas'; end if;
  select * into r from private.preorder_payment_requests
    where preorder_id=p.id for update;
  if not found then raise exception 'To‘lov hisobi topilmadi'; end if;
  if r.payment_state='verified' then
    return jsonb_build_object('payment_state','verified','duplicate',true); end if;
  if r.amount_due>0 and
    (r.payment_state<>'proof_submitted' or r.balance_proof_path='') then
    raise exception 'Qolgan to‘lov cheki yuborilmagan'; end if;
  update private.preorder_payment_requests
    set payment_state='verified',updated_at=now()
    where preorder_id=p.id;
  if trim(coalesce(p.phone,''))<>'' then
    insert into public.customer_push_messages(phone,title,body,kind)
    values(p.phone,'Oldindan zakaz to‘lovi tasdiqlandi ✅',
       'To‘lovingiz tekshirildi. Keyingi bosqich haqida do‘kon xabar beradi.',
       'preorder_balance');
  end if;
  return jsonb_build_object('payment_state','verified','duplicate',false);
end;
$$;
revoke all on function public.admin_native_preorder_payment_confirm(text,bigint)
  from public,anon,authenticated;
grant execute on function public.admin_native_preorder_payment_confirm(text,bigint)
  to service_role;

-- Cancellation releases every additional item, besides the original hold.
create or replace function public.admin_native_preorder_set_status(
  p_secret text,p_id bigint,p_expected_status text,
  p_status text,p_note text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.preorders%rowtype; n text:=trim(coalesce(p_note,''));
        h private.preorder_stock_holds%rowtype; e record;
begin
  if public._admin_secret_ok(p_secret) is not true then raise exception 'Admin ruxsati yo‘q'; end if;
  if p_status not in ('waiting','accepted','cancelled') or p_id is null or length(n)>500 then
    raise exception 'Noto‘g‘ri holat yoki izoh'; end if;
  select * into v from public.preorders where id=p_id for update;
  if not found then raise exception 'Zakaz topilmadi'; end if;
  if exists(select 1 from private.admin_preorder_hidden a where a.source='native' and a.order_id=p_id::text)
    then raise exception 'Arxiv zakazi'; end if;
  if v.status is distinct from p_expected_status then raise exception 'Zakaz holati boshqa oynada o‘zgargan'; end if;
  if v.status=p_status then return jsonb_build_object('status',p_status,'duplicate',true); end if;
  if not ((v.status='waiting' and p_status in ('accepted','cancelled')) or
    (v.status='contacted' and p_status in ('accepted','cancelled')) or
    (v.status='accepted' and p_status='cancelled') or
    (v.status='arrived' and p_status='cancelled') or
    (v.status='cancelled' and p_status='waiting')) then raise exception 'Holat o‘tishi noto‘g‘ri'; end if;
  if p_status in ('cancelled','waiting') and length(n)<3 then raise exception 'Sababini yozing'; end if;
  if p_status='cancelled' then
    if exists(select 1 from private.preorder_payment_requests r where r.preorder_id=p_id and r.payment_state='verified')
      then raise exception 'Tasdiqlangan to‘lovni bekor qilishdan oldin qayta hisoblang'; end if;
    for e in select book_id,quantity from private.preorder_extra_holds
      where preorder_id=p_id order by book_id for update
    loop
      delete from private.preorder_extra_holds where preorder_id=p_id and book_id=e.book_id;
      update public.books set stock=stock+e.quantity where id=e.book_id;
    end loop;
    select * into h from private.preorder_stock_holds where preorder_id=p_id for update;
    if found then
      delete from private.preorder_stock_holds where preorder_id=p_id;
      update public.books set stock=stock+h.quantity where id=h.book_id;
    end if;
    update private.preorder_payment_requests set payment_state='cancelled',updated_at=now()
      where preorder_id=p_id;
  end if;
  update public.preorders set status=p_status where id=p_id;
  if p_status='accepted' then
    update public.books set stock=stock where id=v.book_id;
  end if;
  insert into private.admin_preorder_status_events(preorder_id,old_status,new_status,admin_note)
    values(p_id,v.status,p_status,n);
  return jsonb_build_object('status',p_status,'duplicate',false);
end;
$$;
revoke all on function public.admin_native_preorder_set_status(text,bigint,text,text,text) from public,anon,authenticated;
grant execute on function public.admin_native_preorder_set_status(text,bigint,text,text,text) to service_role;
