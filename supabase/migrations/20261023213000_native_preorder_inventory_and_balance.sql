-- Native preorder inventory reservation and deposit settlement.
-- Available books.stock is always EXCLUSIVE of held preorder quantities.
-- All changes are transactional and no existing order or payment is mutated here.
create table if not exists private.preorder_stock_holds (
  preorder_id bigint primary key references public.preorders(id) on delete restrict,
  book_id uuid not null references public.books(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  reserved_at timestamptz not null default now()
);
revoke all on private.preorder_stock_holds from public, anon, authenticated;

create table if not exists private.preorder_payment_requests (
  preorder_id bigint primary key references public.preorders(id) on delete restrict,
  unit_price integer not null check(unit_price > 0),
  shipping_fee integer not null default 0 check(shipping_fee between 0 and 100000),
  base_total integer not null check(base_total >= 0),
  extra_total integer not null default 0 check(extra_total >= 0),
  deposit_credit integer not null check(deposit_credit >= 0),
  amount_due integer not null check(amount_due >= 0),
  admin_note text not null,
  payment_state text not null default 'requested'
    check(payment_state in ('requested','proof_submitted','verified','cancelled')),
  balance_proof_path text not null default '',
  last_notified_at timestamptz,
  updated_at timestamptz not null default now()
);
revoke all on private.preorder_payment_requests from public,anon,authenticated;

-- When an admin receives a fresh batch, automatically allocate accepted
-- preorders BEFORE the new available stock is visible to buyers.
create or replace function private.allocate_preorder_holds_on_book_stock()
returns trigger language plpgsql security definer
set search_path = ''
as $$
declare p record;
begin
  -- Sale deductions must never cause a phantom reservation.
  if new.stock <= 0 or new.stock < old.stock then return new; end if;
  for p in
    select po.id, po.quantity
    from public.preorders po
    where po.book_id=new.id
      and po.status in ('accepted','arrived')
      and not exists(select 1 from private.preorder_stock_holds h
                     where h.preorder_id=po.id)
      and not exists(select 1 from private.admin_preorder_hidden ar
                     where ar.source='native' and ar.order_id=po.id::text)
    order by po.created_at, po.id
  loop
    if new.stock < p.quantity then continue; end if;
    insert into private.preorder_stock_holds(preorder_id,book_id,quantity)
    values(p.id,new.id,p.quantity)
    on conflict(preorder_id) do nothing;
    if found then new.stock:=new.stock-p.quantity; end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists books_preorder_allocate_on_stock on public.books;
create trigger books_preorder_allocate_on_stock
before update of stock on public.books
for each row execute function private.allocate_preorder_holds_on_book_stock();

-- Extend the existing admin native status RPC while preserving cancellation
-- checks, expected-state conflict prevention and private audit trail.
create or replace function public.admin_native_preorder_set_status(
  p_secret text, p_id bigint, p_expected_status text,
  p_status text, p_note text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_row public.preorders%rowtype; v_note text:=trim(coalesce(p_note,''));
        v_hold private.preorder_stock_holds%rowtype;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_id is null or p_status not in ('waiting','accepted','cancelled') or
     length(v_note)>500 then
    raise exception 'Holat yoki izoh noto‘g‘ri';
  end if;
  select * into v_row from public.preorders where id=p_id for update;
  if not found then raise exception 'Oldindan zakaz topilmadi'; end if;
  if exists(select 1 from private.admin_preorder_hidden h
    where h.source='native' and h.order_id=p_id::text) then
    raise exception 'Arxivdagi zakaz boshqarilmaydi';
  end if;
  if v_row.status is distinct from p_expected_status then
    raise exception 'Zakaz boshqa oynada yangilangan. Ro‘yxatni yangilang';
  end if;
  if v_row.status=p_status then
    return jsonb_build_object('status',p_status,'duplicate',true);
  end if;
  if not ((v_row.status='waiting' and p_status in ('accepted','cancelled')) or
    (v_row.status='contacted' and p_status in ('accepted','cancelled')) or
    (v_row.status='accepted' and p_status='cancelled') or
    (v_row.status='arrived' and p_status='cancelled') or
    (v_row.status='cancelled' and p_status='waiting')) then
    raise exception 'Holat o‘tishi mumkin emas';
  end if;
  if p_status in ('cancelled','waiting') and length(v_note)<3 then
    raise exception 'Bekor qilish yoki qayta ochish sababini yozing';
  end if;
  if p_status='cancelled' then
    if exists(select 1 from private.preorder_payment_requests r
      where r.preorder_id=p_id and r.payment_state='verified') then
      raise exception 'To‘lov tasdiqlangan. Avval hisob-kitobni tekshiring';
    end if;
    select * into v_hold from private.preorder_stock_holds
      where preorder_id=p_id for update;
    if found then
      delete from private.preorder_stock_holds where preorder_id=p_id;
      update public.books set stock=stock+v_hold.quantity where id=v_hold.book_id;
    end if;
    update private.preorder_payment_requests set payment_state='cancelled',
      updated_at=now() where preorder_id=p_id;
  end if;
  update public.preorders set status=p_status where id=p_id;
  if p_status='accepted' then
    -- Touch stock atomically: reserve any already available units.
    update public.books set stock=stock where id=v_row.book_id;
  end if;
  insert into private.admin_preorder_status_events
    (preorder_id,old_status,new_status,admin_note)
    values(p_id,v_row.status,p_status,v_note);
  return jsonb_build_object('status',p_status,'previous_status',v_row.status,
    'duplicate',false);
end;
$$;
revoke all on function public.admin_native_preorder_set_status(text,bigint,text,text,text)
  from public, anon, authenticated;
grant execute on function public.admin_native_preorder_set_status(text,bigint,text,text,text)
  to service_role;

-- Only a true, physically reserved arrival can generate a payment request.
-- Admin manually confirms unit price and courier fee. The original deposit
-- is applied exactly once and cannot exceed the final amount without review.
create or replace function public.admin_native_preorder_arrive_invoice(
  p_secret text, p_id bigint, p_expected_status text,
  p_unit_price integer, p_shipping_fee integer, p_note text
) returns jsonb language plpgsql security definer set search_path=''
as $$
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
  v_total:=v.quantity::bigint*p_unit_price+p_shipping_fee;
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
$$;
revoke all on function public.admin_native_preorder_arrive_invoice(text,bigint,text,integer,integer,text)
  from public,anon,authenticated;
grant execute on function public.admin_native_preorder_arrive_invoice(text,bigint,text,integer,integer,text)
  to service_role;

-- Admin listing includes current accounting without exposing private tables
-- directly to unauthenticated clients.
create or replace function public.admin_preorders_all_list(
  p_secret text, p_limit integer default 200, p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path=''
as $$
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
       r.unit_price,r.shipping_fee,r.base_total,r.extra_total,
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
$$;
revoke all on function public.admin_preorders_all_list(text,integer,integer)
  from public,anon,authenticated;
grant execute on function public.admin_preorders_all_list(text,integer,integer)
  to service_role;
