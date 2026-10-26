-- MB2108-20261027: shared, itemized prepaid ledger for both historic sources.
-- No bank transfer/refund is automated. Evidence is retained in private tables.
create table if not exists private.release_preorder_invoices (
 source text not null check(source in ('native','web')), reference text not null,
 deposit_credit bigint not null check(deposit_credit>=0), price_ready boolean not null default false,
 payment_state text not null default 'requested' check(payment_state in ('requested','proof_submitted','verified','cancelled')),
 shipping_fee integer not null default 4000 check(shipping_fee in (0,4000)),
 base_total bigint not null default 0, extra_total bigint not null default 0,
 amount_due bigint not null default 0 check(amount_due>=0), refund_due bigint not null default 0 check(refund_due>=0),
 submitted_amount bigint not null default 0, balance_paid bigint not null default 0,
 balance_proof_path text not null default '', delivery_type text not null default '택배',
 recipient_name text not null default '', recipient_phone text not null default '',
 delivery_address text not null default '', delivery_saved boolean not null default false,
 admin_note text not null default '', converted_order_id uuid unique,
 revision bigint not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 primary key(source,reference)
);
create table if not exists private.release_preorder_lines (
 source text not null, reference text not null, kind text not null check(kind in ('main','extra')),
 book_id uuid not null references public.books(id), title text not null,
 quantity integer not null check(quantity between 1 and 200), unit_price integer not null check(unit_price>0),
 unit_cost integer not null default 0 check(unit_cost>=0), held integer not null default 0 check(held>=0 and held<=quantity),
 primary key(source,reference,kind,book_id),
 foreign key(source,reference) references private.release_preorder_invoices(source,reference)
);
create table if not exists private.release_conversion_orders (
 order_id uuid primary key, source text not null, reference text not null,
 items jsonb not null, subtotal integer not null, delivery_fee integer not null, created_at timestamptz not null default now(),
 unique(source,reference), foreign key(source,reference) references private.release_preorder_invoices(source,reference)
);
create table if not exists private.release_audit_backups (
 kind text not null, reference text not null, payload jsonb not null, created_at timestamptz not null default now(), primary key(kind,reference)
);
alter table private.release_preorder_invoices enable row level security;
alter table private.release_preorder_lines enable row level security;
alter table private.release_conversion_orders enable row level security;
alter table private.release_audit_backups enable row level security;
revoke all on private.release_preorder_invoices, private.release_preorder_lines, private.release_conversion_orders, private.release_audit_backups from public,anon,authenticated;

create or replace function private.release_preorder_context(p_source text,p_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if p_source='native' then
  select to_jsonb(p)||jsonb_build_object('title',b.title,'source','native','id',p.id::text)
   into r from public.preorders p left join public.books b on b.id=p.book_id where p.id=p_id::bigint;
 elsif p_source='web' then
  select to_jsonb(w)||jsonb_build_object('title',w.book_title,'source','web','id',w.id::text)
   into r from public.web_preorder_requests w where w.id=p_id::uuid;
 else raise exception 'Zakas turi noto‘g‘ri'; end if;
 if r is null then raise exception 'Oldindan zakas topilmadi'; end if;
 return r;
end $$;

create or replace function private.release_assert_owner(p_session text,p_source text,p_id text) returns text
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); r jsonb;
begin
 if k is null then raise exception 'PIN bilan qayta kiring'; end if;
 r:=private.release_preorder_context(p_source,p_id);
 if public._customer_phone_key(r->>'phone')<>k or not (
   exists(select 1 from private.customer_pin_devices d where d.phone_key=k and d.install_id=r->>'install_id')
   or (p_source='web' and nullif(r->>'install_id','') is null and exists(
    select 1 from private.customer_pin_profiles p where p.phone_key=k and lower(regexp_replace(trim(p.full_name),'\s+',' ','g'))=lower(regexp_replace(trim(r->>'customer_name'),'\s+',' ','g'))))
 ) then raise exception 'Bu zakas profilingizga tegishli emas'; end if;
 return k;
end $$;

create or replace function private.release_book_price(p_book public.books) returns integer
language sql stable set search_path='' as $$
 select case when p_book.discount_percent>0 and (p_book.discount_ends_at is null or p_book.discount_ends_at>now())
 then round(p_book.price*(100-least(99,p_book.discount_percent))/100.0)::integer else p_book.price end
$$;

create or replace function private.release_preorder_ensure(p_source text,p_id text) returns void
language plpgsql security definer set search_path='' as $$
declare r jsonb; b public.books%rowtype; h integer:=0; ex record;
begin
 perform pg_advisory_xact_lock(hashtextextended('release-preorder:'||p_source||':'||p_id,27));
 if exists(select 1 from private.release_preorder_invoices where source=p_source and reference=p_id) then return; end if;
 r:=private.release_preorder_context(p_source,p_id);
 insert into private.release_preorder_invoices(source,reference,deposit_credit,recipient_name,recipient_phone,payment_state)
 values(p_source,p_id,greatest(coalesce((r->>'deposit_amount')::bigint,0),0),coalesce(r->>'customer_name',''),coalesce(r->>'phone',''),
   case when r->>'status'='cancelled' then 'cancelled' else 'requested' end);
 if nullif(r->>'book_id','') is not null then
  select * into b from public.books where id=(r->>'book_id')::uuid;
  if found and b.price>0 then
   if p_source='native' then
    select coalesce(quantity,0) into h from private.preorder_stock_holds where preorder_id=p_id::bigint;
    h:=coalesce(h,0);
   end if;
   insert into private.release_preorder_lines(source,reference,kind,book_id,title,quantity,unit_price,unit_cost,held)
   values(p_source,p_id,'main',b.id,b.title,(r->>'quantity')::integer,private.release_book_price(b),coalesce(b.cost_price,0),h);
   if p_source='native' then delete from private.preorder_stock_holds where preorder_id=p_id::bigint; end if;
  end if;
 end if;
 if p_source='native' then
  for ex in select e.*,bk.title,bk.cost_price from private.preorder_extra_holds e join public.books bk on bk.id=e.book_id where e.preorder_id=p_id::bigint loop
   insert into private.release_preorder_lines values(p_source,p_id,'extra',ex.book_id,ex.title,ex.quantity,ex.unit_price,coalesce(ex.cost_price,0),ex.quantity);
  end loop;
  delete from private.preorder_extra_holds where preorder_id=p_id::bigint;
 else
  for ex in select e.*,bk.title,bk.cost_price from private.web_preorder_checkout_items e join public.books bk on bk.id=e.book_id where e.preorder_id=p_id::uuid loop
   insert into private.release_preorder_lines values(p_source,p_id,'extra',ex.book_id,ex.title,ex.quantity,ex.unit_price,coalesce(ex.cost_price,0),ex.quantity);
  end loop;
  delete from private.web_preorder_checkout_items where preorder_id=p_id::uuid;
 end if;
end $$;

create or replace function private.release_preorder_recalculate(p_source text,p_id text) returns void
language plpgsql security definer set search_path='' as $$
declare inv private.release_preorder_invoices%rowtype; main_sum bigint; extras bigint; qty integer; shipping integer; blocked boolean;
begin
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id for update;
 select coalesce(sum(quantity::bigint*unit_price) filter(where kind='main'),0),coalesce(sum(quantity::bigint*unit_price) filter(where kind='extra'),0),coalesce(sum(quantity),0)
 into main_sum,extras,qty from private.release_preorder_lines where source=p_source and reference=p_id;
 -- Only the books in THIS invoice can change its free-postage eligibility.
 select exists(select 1 from private.release_preorder_lines l join public.books b on b.id=l.book_id
 where l.source=p_source and l.reference=p_id and b.discount_percent>0 and (b.discount_ends_at is null or b.discount_ends_at>now()) and b.discount_free_delivery=false) into blocked;
 shipping:=case when inv.delivery_type in ('경산 직접수령','경산 무료배송') then 0 when qty>=4 and not blocked then 0 else 4000 end;
 if main_sum+extras+shipping>100000000 then raise exception 'Jami summa limitdan oshdi'; end if;
 if inv.payment_state in ('proof_submitted','verified') and greatest(main_sum+extras+shipping-inv.deposit_credit,0)>greatest(inv.submitted_amount,inv.balance_paid) then
  raise exception 'Yangi summa eski to‘lov chekidan ko‘p. Admin bilan bog‘laning'; end if;
 update private.release_preorder_invoices set shipping_fee=shipping,base_total=main_sum+shipping,extra_total=extras,
  amount_due=greatest(main_sum+extras+shipping-deposit_credit-balance_paid,0),
  refund_due=greatest(deposit_credit+balance_paid-main_sum-extras-shipping,0),revision=revision+1,updated_at=now()
  where source=p_source and reference=p_id;
end $$;

create or replace function private.release_preorder_detail(p_source text,p_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb; inv private.release_preorder_invoices%rowtype; lines jsonb; main_lines jsonb; extra_lines jsonb;
begin
 r:=private.release_preorder_context(p_source,p_id);
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id;
 select coalesce(jsonb_agg(jsonb_build_object('book_id',book_id,'title',title,'quantity',quantity,'unit_price',unit_price,'held',held,'kind',kind) order by kind,book_id),'[]')
 into lines from private.release_preorder_lines where source=p_source and reference=p_id;
 select coalesce(jsonb_agg(x),'[]') into main_lines from jsonb_array_elements(lines) x where x->>'kind'='main';
 select coalesce(jsonb_agg(x),'[]') into extra_lines from jsonb_array_elements(lines) x where x->>'kind'='extra';
 return r||jsonb_build_object('price_ready',coalesce(inv.price_ready,false),'deposit_credit',coalesce(inv.deposit_credit,(r->>'deposit_amount')::bigint),
 'base_total',inv.base_total,'extra_total',inv.extra_total,'amount_due',inv.amount_due,'shipping_fee',inv.shipping_fee,'refund_due',inv.refund_due,
 'shipping_refund_due',case when inv.payment_state in ('proof_submitted','verified') then greatest(inv.submitted_amount-(inv.base_total+inv.extra_total-inv.deposit_credit),0) else 0 end,
 'payment_state',inv.payment_state,'revision',inv.revision,'extras',extra_lines,'main_items',main_lines,'items',lines,
 'unit_price',case when jsonb_array_length(main_lines)=1 then (main_lines->0->>'unit_price')::integer else 0 end,
 'can_edit',r->>'status'='arrived' and inv.payment_state='requested','recipient_name',coalesce(nullif(inv.recipient_name,''),r->>'customer_name'),
 'recipient_phone',coalesce(nullif(inv.recipient_phone,''),r->>'phone'),'delivery_address',inv.delivery_address,'delivery_type',coalesce(inv.delivery_type,'택배'),
 'delivery_saved',coalesce(inv.delivery_saved,false),'balance_proof_path',inv.balance_proof_path,'converted_order_id',inv.converted_order_id,'admin_note',inv.admin_note);
end $$;

create or replace function private.release_allocate_stock() returns trigger
language plpgsql security definer set search_path='' as $$
declare l record; needed integer; r jsonb;
begin
 if new.stock<=0 or new.stock<old.stock then return new; end if;
 for l in select x.* from private.release_preorder_lines x join private.release_preorder_invoices i using(source,reference)
  where x.book_id=new.id and x.held<x.quantity and i.payment_state in ('requested','proof_submitted')
  order by i.created_at,x.source,x.reference,x.kind for update of x skip locked loop
  r:=private.release_preorder_context(l.source,l.reference);
  if r->>'status' not in ('accepted','contacted','arrived') then continue; end if;
  needed:=l.quantity-l.held;
  if new.stock<needed then continue; end if;
  new.stock:=new.stock-needed;
  update private.release_preorder_lines set held=quantity where source=l.source and reference=l.reference and kind=l.kind and book_id=l.book_id;
 end loop;
 return new;
end $$;
drop trigger if exists books_release_preorder_allocate on public.books;
create trigger books_release_preorder_allocate before update of stock on public.books for each row execute function private.release_allocate_stock();

create or replace function private.release_cancel_preorder(p_source text,p_id text) returns void
language plpgsql security definer set search_path='' as $$
declare l record; inv private.release_preorder_invoices%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('release-preorder:'||p_source||':'||p_id,27));
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id for update;
 if found then
  if inv.converted_order_id is not null then
   raise exception 'To‘langan zakasni avval buyurtmalar bo‘limida bekor qiling'; end if;
  update private.release_preorder_invoices set payment_state='cancelled',amount_due=0,refund_due=deposit_credit+balance_paid,revision=revision+1,updated_at=now() where source=p_source and reference=p_id;
  for l in select * from private.release_preorder_lines where source=p_source and reference=p_id and held>0 order by book_id for update loop
   update private.release_preorder_lines set held=0 where source=l.source and reference=l.reference and kind=l.kind and book_id=l.book_id;
   update public.books set stock=stock+l.held where id=l.book_id;
  end loop;
 end if;
 if p_source='web' then
  insert into private.release_audit_backups(kind,reference,payload)
   select 'cancelled_web_checkout',p_id,to_jsonb(c) from private.web_preorder_checkout c where c.preorder_id=p_id::uuid on conflict do nothing;
  update private.web_preorder_checkout set payment_state='cancelled',amount_due=0,updated_at=now() where preorder_id=p_id::uuid;
  for l in select * from private.web_preorder_checkout_items where preorder_id=p_id::uuid order by book_id for update loop
   delete from private.web_preorder_checkout_items where preorder_id=p_id::uuid and book_id=l.book_id;
   update public.books set stock=stock+l.quantity where id=l.book_id;
  end loop;
 end if;
end $$;

-- Admin actions and customer actions use the same ledger and row lock.
create or replace function public.admin_release_preorder(p_secret text,p_source text,p_id text,p_action text default 'detail',p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb; inv private.release_preorder_invoices%rowtype; x jsonb; l record; b public.books%rowtype;
 st text; q integer; total_qty integer:=0; oid uuid; items jsonb; subtotal bigint;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 perform private.release_preorder_ensure(p_source,p_id);
 r:=private.release_preorder_context(p_source,p_id);
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id for update;
 if p_action='detail' then return private.release_preorder_detail(p_source,p_id); end if;
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
  perform public.admin_accept_order_with_note(p_secret,oid,inv.admin_note);
  update private.release_preorder_invoices set balance_paid=submitted_amount,amount_due=0,payment_state='verified',converted_order_id=oid,revision=revision+1,updated_at=now() where source=p_source and reference=p_id;
  -- The normal order now owns the allocation, including cancellation/restock.
  update private.release_preorder_lines set held=0 where source=p_source and reference=p_id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.release_preorder_detail(p_source,p_id);
end $$;

create or replace function public.customer_release_preorders(p_session text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); r record; result jsonb:='[]';
begin
 if k is null then raise exception 'PIN bilan kiring'; end if;
 for r in select 'native' as source,p.id::text as reference,p.created_at from public.preorders p
  where public._customer_phone_key(p.phone)=k and exists(select 1 from private.customer_pin_devices d where d.phone_key=k and d.install_id=p.install_id)
  union all select 'web',w.id::text,w.created_at from public.web_preorder_requests w
  where public._customer_phone_key(w.phone)=k and (exists(select 1 from private.customer_pin_devices d where d.phone_key=k and d.install_id=w.install_id)
   or (nullif(w.install_id,'') is null and exists(select 1 from private.customer_pin_profiles p where p.phone_key=k and lower(trim(p.full_name))=lower(trim(w.customer_name)))))
  order by created_at desc loop
  perform private.release_preorder_ensure(r.source,r.reference);
  result:=result||jsonb_build_array(private.release_preorder_detail(r.source,r.reference));
 end loop;
 return result;
end $$;

create or replace function private.release_cancel_preorder_trigger() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status='cancelled' and old.status is distinct from new.status then
  perform private.release_cancel_preorder(case when tg_table_name='preorders' then 'native' else 'web' end,new.id::text);
 end if;
 return new;
end $$;
drop trigger if exists release_cancel_preorder on public.preorders;
create trigger release_cancel_preorder after update of status on public.preorders for each row execute function private.release_cancel_preorder_trigger();
drop trigger if exists release_cancel_preorder on public.web_preorder_requests;
create trigger release_cancel_preorder after update of status on public.web_preorder_requests for each row execute function private.release_cancel_preorder_trigger();

create or replace function public.customer_release_preorder(p_session text,p_source text,p_id text,p_action text default 'detail',p_payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text; r jsonb; inv private.release_preorder_invoices%rowtype; b public.books%rowtype; l private.release_preorder_lines%rowtype;
 delta integer; next_qty integer; receipt_path text; dest text; dtype text; digits text; n text;
begin
 k:=private.release_assert_owner(p_session,p_source,p_id);
 perform private.release_preorder_ensure(p_source,p_id);
 r:=private.release_preorder_context(p_source,p_id);
 select * into inv from private.release_preorder_invoices where source=p_source and reference=p_id for update;
 if p_action='detail' then return private.release_preorder_detail(p_source,p_id); end if;
 if r->>'status'<>'arrived' or inv.payment_state='cancelled' or not inv.price_ready then raise exception 'Kitob kelmagan yoki yakuniy narx belgilanmagan'; end if;
 if p_payload?'revision' and (p_payload->>'revision')::bigint<>inv.revision then raise exception 'Hisob boshqa oynada o‘zgardi. Yangilang'; end if;
 if p_action='add' then
  if inv.payment_state<>'requested' then raise exception 'To‘lov yuborilgan. Savat yopiq'; end if;
  delta:=(p_payload->>'delta')::integer;
  if delta is null or delta=0 or abs(delta)>5 then raise exception 'Miqdor noto‘g‘ri'; end if;
  select * into b from public.books where id=(p_payload->>'book_id')::uuid for update;
  if not found or (delta>0 and (not b.is_active or b.price<=0 or b.preorder_enabled)) then raise exception 'Kitob sotuvda mavjud emas'; end if;
  if exists(select 1 from private.release_preorder_lines where source=p_source and reference=p_id and kind='main' and book_id=b.id) then raise exception 'Asosiy kitob allaqachon zakasda bor'; end if;
  select * into l from private.release_preorder_lines where source=p_source and reference=p_id and kind='extra' and book_id=b.id for update;
  next_qty:=coalesce(l.quantity,0)+delta;
  if next_qty<0 or next_qty>10 or (delta>0 and b.stock<delta) then raise exception 'Ombor yoki miqdor yetarli emas'; end if;
  if next_qty=0 then delete from private.release_preorder_lines where source=p_source and reference=p_id and kind='extra' and book_id=b.id;
  else insert into private.release_preorder_lines(source,reference,kind,book_id,title,quantity,unit_price,unit_cost,held)
   values(p_source,p_id,'extra',b.id,b.title,next_qty,coalesce(l.unit_price,private.release_book_price(b)),coalesce(l.unit_cost,b.cost_price,0),next_qty)
   on conflict(source,reference,kind,book_id) do update set quantity=excluded.quantity,held=excluded.held;
  end if;
  update public.books set stock=stock-delta where id=b.id;
  perform private.release_preorder_recalculate(p_source,p_id);
 elsif p_action='delivery' then
  n:=trim(coalesce(p_payload->>'recipient_name','')); digits:=regexp_replace(coalesce(p_payload->>'recipient_phone',''),'[^0-9]','','g');
  dest:=trim(coalesce(p_payload->>'address','')); dtype:=p_payload->>'delivery_type';
  if length(n) not between 2 and 80 or digits !~ '^010[0-9]{8}$' or dtype not in ('택배','경산 직접수령','경산 무료배송') or length(dest)>500 or (dtype<>'경산 직접수령' and length(dest)<8) then raise exception 'Ism, telefon va manzilni tekshiring'; end if;
  if dtype='경산 무료배송' and dest !~ '경산' and lower(dest) !~ 'gyeongsan' then raise exception 'Gyeongsan manzilini kiriting'; end if;
  if inv.payment_state='verified' then raise exception 'To‘langan zakas manzilini admin bilan o‘zgartiring'; end if;
  update private.release_preorder_invoices set recipient_name=n,recipient_phone=digits,delivery_address=case when dtype='경산 직접수령' then dtype else dest end,delivery_type=dtype,delivery_saved=true where source=p_source and reference=p_id;
  perform private.release_preorder_recalculate(p_source,p_id);
 elsif p_action='proof' then
  receipt_path:=trim(coalesce(p_payload->>'path',''));
  if inv.payment_state='proof_submitted' and inv.balance_proof_path=receipt_path then return private.release_preorder_detail(p_source,p_id); end if;
  if inv.payment_state<>'requested' or inv.amount_due<=0 or not inv.delivery_saved then raise exception 'Avval manzil va qolgan summani tekshiring'; end if;
  if receipt_path !~ '^receipts/[A-Za-z0-9._/-]+$' or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=receipt_path) then raise exception 'Chek fayli serverga yuklanmagan'; end if;
  if not exists(select 1 from private.release_receipt_claims c where c.path=receipt_path and c.phone_key=k) then raise exception 'Chek profilingizga tegishli emas'; end if;
  if exists(select 1 from private.release_preorder_invoices x where x.balance_proof_path=receipt_path and (x.source,x.reference)<>(p_source,p_id)) then raise exception 'Bu chek boshqa zakasda ishlatilgan'; end if;
  update private.release_preorder_invoices set balance_proof_path=receipt_path,submitted_amount=amount_due,payment_state='proof_submitted',revision=revision+1,updated_at=now() where source=p_source and reference=p_id;
 else raise exception 'Noto‘g‘ri amal'; end if;
 return private.release_preorder_detail(p_source,p_id);
end $$;

-- Preserve the tested pricing rules as pure record transformations for quoting.
CREATE OR REPLACE FUNCTION private.release_prepare_order(p_order public.orders)
 RETURNS public.orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new public.orders := p_order;
 item jsonb; bid uuid; qty integer; b public.books%rowtype; unit_price integer; line_total integer;
 safe_items jsonb:='[]'::jsonb; safe_subtotal integer:=0; safe_count integer:=0; safe_delivery integer:=4000;
 is_gyeongsan_pickup boolean:=false; effective_discount integer; has_active_discount boolean:=false; discount_free_delivery boolean:=true;
 sel jsonb; bundle public.book_bundles%rowtype; bi record; cart_qty integer; needed_qty integer; bundle_live_total integer; bundle_saving integer;
 total_bundle_discount integer:=0; bundle_shipping boolean:=false;
 bundle_physical_count integer:=0; bundle_count integer:=0; bundle_book_count integer:=0; display_count integer:=0;
 safe_bundles jsonb:='[]'::jsonb;
begin
 if new.source='telegram' then
  new.delivery_type:='택배';
  new.delivery_fee:=case when coalesce((select sum(greatest(0,coalesce((x->>'quantity')::int,0))) from jsonb_array_elements(new.items)x),0)>=4 then 0 else 4000 end;
  new.subtotal:=greatest(0,coalesce(new.subtotal,0)); new.total:=new.subtotal+new.delivery_fee; return new;
 end if;

 new.source:='app';
 new.customer_name:=trim(coalesce(new.customer_name,''));
 new.phone:=trim(coalesce(new.phone,''));
 new.address:=trim(coalesce(new.address,''));
 is_gyeongsan_pickup:=lower(trim(coalesce(new.delivery_type,''))) in ('gyeongsan','경산 직접수령');

 if length(new.customer_name)<2 then raise exception 'Ismni to‘liq kiriting'; end if;
 if length(regexp_replace(new.phone,'\D','','g'))<7 then raise exception 'Telefon raqam noto‘g‘ri'; end if;
 if not is_gyeongsan_pickup and length(new.address)<8 then raise exception 'Manzilni to‘liq kiriting'; end if;
 if is_gyeongsan_pickup and length(new.address)<8 then new.address:='경산 직접수령 (Gyeongsan pickup)'; end if;
 if jsonb_typeof(new.items)<>'array' or jsonb_array_length(new.items)=0 then raise exception 'Buyurtma savatchasi bo‘sh'; end if;
 if jsonb_array_length(new.items)>50 then raise exception 'Buyurtmada juda ko‘p turdagi kitob bor'; end if;

 for item in select * from jsonb_array_elements(new.items) loop
  begin bid:=(item->>'book_id')::uuid; qty:=(item->>'quantity')::integer;
  exception when others then raise exception 'Buyurtma tarkibi noto‘g‘ri'; end;
  if qty is null or qty<=0 or qty>100 then raise exception 'Noto‘g‘ri kitob soni'; end if;
  select * into b from public.books where id=bid and is_active=true;
  if not found then raise exception 'Kitob topilmadi yoki sotuvda emas'; end if;
  if b.price<=0 then raise exception 'Kitob narxi noto‘g‘ri'; end if;
  if b.stock<qty then raise exception '“%” omborda yetarli emas',b.title; end if;

  effective_discount:=case
    when b.discount_percent>0 and (b.discount_ends_at is null or b.discount_ends_at>clock_timestamp())
    then greatest(0,least(99,b.discount_percent)) else 0 end;
  if effective_discount>0 then
    has_active_discount:=true;
    discount_free_delivery:=discount_free_delivery and coalesce(b.discount_free_delivery,true);
  end if;

  unit_price:=round(b.price*(100-effective_discount)/100.0)::integer;
  line_total:=unit_price*qty;
  safe_subtotal:=safe_subtotal+line_total;
  safe_count:=safe_count+qty;
  safe_items:=safe_items||jsonb_build_array(jsonb_build_object(
    'book_id',b.id,'title',b.title,'quantity',qty,'original_price',b.price,
    'discount_percent',effective_discount,'price',unit_price,'unit_price',unit_price,'line_total',line_total));
 end loop;

 if jsonb_typeof(coalesce(new.bundle_selections,'[]'::jsonb))='array' then
  for sel in select * from jsonb_array_elements(coalesce(new.bundle_selections,'[]'::jsonb))
  loop
   select * into bundle from public.book_bundles
   where id=(sel->>'bundle_id')::uuid and is_active=true;
   if not found then raise exception 'Kitob seti topilmadi yoki faol emas'; end if;

   bundle_live_total:=0;
   bundle_book_count:=0;
   for bi in
    select i.book_id,i.quantity,bk.price,bk.discount_percent,bk.discount_ends_at
    from public.book_bundle_items i join public.books bk on bk.id=i.book_id
    where i.bundle_id=bundle.id
   loop
    select coalesce(sum((x->>'quantity')::int),0) into cart_qty
    from jsonb_array_elements(new.items)x
    where (x->>'book_id')::uuid=bi.book_id;

    select coalesce(sum(i2.quantity),0) into needed_qty
    from jsonb_array_elements(coalesce(new.bundle_selections,'[]'::jsonb)) s2
    join public.book_bundles bb on bb.id=(s2->>'bundle_id')::uuid
    join public.book_bundle_items i2 on i2.bundle_id=bb.id
    where i2.book_id=bi.book_id;

    if cart_qty<needed_qty then raise exception 'Set tarkibi savatchada to‘liq emas'; end if;

    effective_discount:=case
      when bi.discount_percent>0 and (bi.discount_ends_at is null or bi.discount_ends_at>clock_timestamp())
      then greatest(0,least(99,bi.discount_percent)) else 0 end;
    bundle_live_total:=bundle_live_total+
      round(bi.price*(100-effective_discount)/100.0)::integer*bi.quantity;
    bundle_book_count:=bundle_book_count+bi.quantity;
   end loop;

   bundle_saving:=greatest(0,bundle_live_total-bundle.price);
   total_bundle_discount:=total_bundle_discount+bundle_saving;
   bundle_shipping:=bundle_shipping or bundle.delivery_included;
   bundle_physical_count:=bundle_physical_count+bundle_book_count;
   bundle_count:=bundle_count+1;

   safe_bundles:=safe_bundles||jsonb_build_array(jsonb_build_object(
     'bundle_id',bundle.id,
     'title',bundle.title,
     'price',bundle.price,
     'regular_total',bundle_live_total,
     'saving',bundle_saving,
     'book_count',bundle_book_count,
     'delivery_included',bundle.delivery_included
   ));
  end loop;
 end if;

 total_bundle_discount:=least(total_bundle_discount,safe_subtotal);
 safe_subtotal:=safe_subtotal-total_bundle_discount;

 -- Muhim: set ichidagi 2/3/4/5 ta kitob pochta aksiyasida alohida sanalmaydi.
 -- Har bir set savatchada aynan 1 ta mahsulot hisoblanadi.
 display_count:=greatest(0,safe_count-bundle_physical_count)+bundle_count;

 safe_delivery:=case
  when is_gyeongsan_pickup then 0
  when bundle_shipping then 0
  when display_count>=4 and (not has_active_discount or discount_free_delivery) then 0
  else 4000 end;

 new.delivery_type:=case when is_gyeongsan_pickup then '경산 직접수령' else '택배' end;
 new.items:=safe_items;
 new.bundle_selections:=safe_bundles;
 new.subtotal:=safe_subtotal;
 new.bundle_discount:=total_bundle_discount;
 new.bundle_delivery_included:=bundle_shipping;
 new.delivery_fee:=safe_delivery;
 new.total:=safe_subtotal+safe_delivery;
 new.status:='new';
 new.stock_reserved:=false;
 new.stock_restored:=false;

 if coalesce(new.payment_proof_path,'')<>'' then
  if new.payment_proof_path!~'^receipts/[A-Za-z0-9._/-]+$' then raise exception 'To‘lov cheki manzili noto‘g‘ri'; end if;
  new.payment_submitted_at:=coalesce(new.payment_submitted_at,now());
 else
  new.payment_proof_path:='';
  new.payment_submitted_at:=null;
 end if;
 return new;
end
$function$
;
create or replace function public.prepare_order_for_review() returns trigger language plpgsql security definer set search_path='' as $$ begin 
  if exists(select 1 from private.release_conversion_orders c where c.order_id=new.id) then
    select c.items,c.subtotal,c.delivery_fee into new.items,new.subtotal,new.delivery_fee from private.release_conversion_orders c where c.order_id=new.id;
    new.total:=new.subtotal+new.delivery_fee; new.stock_reserved:=true; new.stock_restored:=false; new.status:='new'; return new;
  end if;
 return private.release_prepare_order(new); end $$;
CREATE OR REPLACE FUNCTION private.release_finalize_order(p_order public.orders)
 RETURNS public.orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  new public.orders := p_order;
  sel jsonb;
  bun public.book_bundles%rowtype;
  safe_bundles jsonb := '[]'::jsonb;
  bundle_regular integer;
  bundle_books integer;
  bundle_units integer := 0;
  bundle_count integer := 0;
  bundle_item_total integer := 0;
  bundle_price_total integer := 0;
  item_total integer := 0;
  display_count integer;
  has_discount boolean := false;
  allow_four_plus boolean := true;
  item jsonb;
  item_book public.books%rowtype;
  effective_discount integer;
  needed_qty integer;
  available_qty integer;
  bi record;
begin
  if coalesce(new.source,'app') <> 'app' then return new; end if;

  -- prepare_order_for_review has already replaced item prices with trusted
  -- current prices. Recalculate from those trusted rows only.
  select coalesce(sum(
    greatest(0,coalesce((x->>'price')::int,(x->>'unit_price')::int,0)) *
    greatest(0,coalesce((x->>'quantity')::int,0))
  ),0)
  into item_total
  from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) x;

  if jsonb_typeof(coalesce(new.bundle_selections,'[]'::jsonb)) = 'array' then
    for sel in select * from jsonb_array_elements(coalesce(new.bundle_selections,'[]'::jsonb))
    loop
      select * into bun
      from public.book_bundles
      where id = nullif(sel->>'bundle_id','')::uuid and is_active = true;
      if not found then raise exception 'Kitob seti topilmadi yoki faol emas'; end if;

      bundle_regular := 0;
      bundle_books := 0;

      for bi in
        select i.book_id, i.quantity
        from public.book_bundle_items i
        where i.bundle_id=bun.id
      loop
        select coalesce(sum(greatest(0,coalesce((x->>'quantity')::int,0))),0)
          into available_qty
        from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) x
        where nullif(x->>'book_id','')::uuid = bi.book_id;

        select coalesce(sum(i2.quantity),0)
          into needed_qty
        from jsonb_array_elements(coalesce(new.bundle_selections,'[]'::jsonb)) s2
        join public.book_bundle_items i2
          on i2.bundle_id = nullif(s2->>'bundle_id','')::uuid
        where i2.book_id = bi.book_id;

        if available_qty < needed_qty then
          raise exception 'Set tarkibi savatchada to‘liq emas';
        end if;

        select coalesce(sum(
          greatest(0,coalesce((x->>'price')::int,(x->>'unit_price')::int,0))
        ),0)
        into effective_discount
        from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) x
        where nullif(x->>'book_id','')::uuid = bi.book_id;

        -- Each cart line has one trusted unit price. Multiply by the set qty.
        select greatest(0,coalesce((x->>'price')::int,(x->>'unit_price')::int,0))
          into effective_discount
        from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) x
        where nullif(x->>'book_id','')::uuid = bi.book_id
        limit 1;

        bundle_regular := bundle_regular + coalesce(effective_discount,0) * bi.quantity;
        bundle_books := bundle_books + bi.quantity;
      end loop;

      if bundle_books <= 0 then raise exception 'Set tarkibi bo‘sh'; end if;

      bundle_count := bundle_count + 1;
      bundle_units := bundle_units + bundle_books;
      bundle_item_total := bundle_item_total + bundle_regular;
      bundle_price_total := bundle_price_total + bun.price;

      safe_bundles := safe_bundles || jsonb_build_array(jsonb_build_object(
        'bundle_id', bun.id,
        'title', bun.title,
        'price', bun.price,
        'regular_total', bundle_regular,
        'saving', greatest(0,bundle_regular-bun.price),
        'delivery_included', bun.delivery_included,
        'book_count', bundle_books
      ));
    end loop;
  end if;

  if bundle_item_total > item_total then
    raise exception 'Set tarkibi savatcha hisobidan oshib ketdi';
  end if;

  -- Exact rule: standalone books keep their trusted current prices and every
  -- set contributes exactly the admin-defined set price, even when that set
  -- price is above the sum of its books (for example shipping-included sets).
  new.subtotal := greatest(0, item_total - bundle_item_total) + bundle_price_total;
  new.bundle_discount := greatest(0, bundle_item_total - bundle_price_total);
  new.bundle_selections := safe_bundles;

  display_count := greatest(0,
    coalesce((select sum(greatest(0,coalesce((x->>'quantity')::int,0)))
              from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) x),0)
    - bundle_units
  ) + bundle_count;

  for item in select * from jsonb_array_elements(coalesce(new.items,'[]'::jsonb))
  loop
    select * into item_book
    from public.books
    where id=nullif(item->>'book_id','')::uuid;
    if found then
      effective_discount := case
        when item_book.discount_percent>0
         and (item_book.discount_ends_at is null or item_book.discount_ends_at>clock_timestamp())
        then greatest(0,least(99,item_book.discount_percent))
        else 0
      end;
      if effective_discount>0 then
        has_discount := true;
        allow_four_plus := allow_four_plus and coalesce(item_book.discount_free_delivery,true);
      end if;
    end if;
  end loop;

  new.bundle_delivery_included :=
    exists(select 1 from jsonb_array_elements(safe_bundles) x
           where coalesce((x->>'delivery_included')::boolean,false));

  if lower(trim(coalesce(new.delivery_type,''))) in ('gyeongsan','경산 직접수령') then
    new.delivery_fee := 0;
  elsif new.bundle_delivery_included then
    new.delivery_fee := 0;
  elsif display_count >= 4 and (not has_discount or allow_four_plus) then
    new.delivery_fee := 0;
  else
    new.delivery_fee := 4000;
  end if;

  new.total := new.subtotal + new.delivery_fee;
  return new;
end;
$function$
;
create or replace function private.finalize_app_bundle_order() returns trigger language plpgsql security definer set search_path='' as $$ begin 
  if exists(select 1 from private.release_conversion_orders c where c.order_id=new.id) then
    select c.items,c.subtotal,c.delivery_fee into new.items,new.subtotal,new.delivery_fee from private.release_conversion_orders c where c.order_id=new.id;
    new.total:=new.subtotal+new.delivery_fee; new.stock_reserved:=true; new.stock_restored:=false; new.status:='new'; return new;
  end if;
 return private.release_finalize_order(new); end $$;
CREATE OR REPLACE FUNCTION private.reserve_app_order_stock_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  rec record;
  v_title text;
  v_stock integer;
begin
  if exists(select 1 from private.release_conversion_orders c where c.order_id=new.id) then new.stock_reserved:=true; new.stock_restored:=false; return new; end if;
  if coalesce(new.source, 'app') <> 'app' then
    return new;
  end if;

  if new.status <> 'new' then
    raise exception 'Yangi buyurtma holati noto‘g‘ri';
  end if;

  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) = 0 then
    raise exception 'Buyurtma savatchasi bo‘sh';
  end if;

  -- Bir xil kitob payload ichida takrorlansa ham umumiy son bo‘yicha tekshiramiz.
  -- FOR UPDATE bir vaqtdagi ikki buyurtmaning oxirgi dona uchun poygasini to‘xtatadi.
  for rec in
    select (x->>'book_id')::uuid as book_id,
           sum((x->>'quantity')::integer)::integer as qty
    from jsonb_array_elements(new.items) as x
    group by (x->>'book_id')::uuid
    order by (x->>'book_id')::uuid
  loop
    select b.title, b.stock
      into v_title, v_stock
      from public.books b
     where b.id = rec.book_id
       and b.is_active = true
     for update;

    if not found then
      raise exception 'Buyurtmadagi kitob topilmadi yoki sotuvda emas';
    end if;
    if rec.qty <= 0 then
      raise exception 'Buyurtmadagi kitob soni noto‘g‘ri';
    end if;
    if v_stock < rec.qty then
      raise exception '“%” omborda yetarli emas. Hozir % dona bor', v_title, v_stock;
    end if;
  end loop;

  for rec in
    select (x->>'book_id')::uuid as book_id,
           sum((x->>'quantity')::integer)::integer as qty
    from jsonb_array_elements(new.items) as x
    group by (x->>'book_id')::uuid
  loop
    update public.books
       set stock = stock - rec.qty
     where id = rec.book_id;
  end loop;

  new.stock_reserved := true;
  new.stock_restored := false;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION private.allocate_preorder_holds_on_book_stock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p record;
begin
  -- Sale deductions must never cause a phantom reservation.
  if new.stock <= 0 or new.stock < old.stock then return new; end if;
  for p in
    select po.id, po.quantity
    from public.preorders po
    where po.book_id=new.id
      and po.status in ('accepted','arrived')
      and not exists(select 1 from private.release_preorder_invoices i where i.source='native' and i.reference=po.id::text)
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
$function$
;
CREATE OR REPLACE FUNCTION public.customer_order_submit(p_order jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_id uuid;
  v_subtotal int;
  v_delivery_fee int;
begin
  if coalesce((p_order->>'entered_by_admin')::boolean,false) then raise exception 'Professional buyurtma uchun yangilangan ilovada admin bilan kiring'; end if;
  v_id := coalesce(nullif(p_order->>'id','')::uuid, gen_random_uuid());
  v_subtotal := coalesce((p_order->>'manual_subtotal')::int, (p_order->>'subtotal')::int, 0);
  v_delivery_fee := case
    when coalesce(p_order->>'delivery_type','택배') = '경산 직접수령' then 0
    else coalesce((p_order->>'delivery_fee')::int,0)
  end;

  insert into public.orders(
    id, customer_name, phone, address, delivery_type, delivery_fee,
    subtotal, total, status, source, items, bundle_selections,
    payment_proof_path, payment_submitted_at,
    instagram_handle, order_note, entered_by_admin, payment_status
  ) values (
    v_id,
    coalesce(p_order->>'customer_name',''),
    coalesce(p_order->>'phone',''),
    coalesce(p_order->>'address',''),
    coalesce(p_order->>'delivery_type','택배'),
    v_delivery_fee,
    v_subtotal,
    v_subtotal + v_delivery_fee,
    'new',
    'app',
    coalesce(p_order->'items','[]'::jsonb),
    coalesce(p_order->'bundle_selections','[]'::jsonb),
    coalesce(p_order->>'payment_proof_path',''),
    case when coalesce(p_order->>'payment_submitted_at','')='' then null
         else (p_order->>'payment_submitted_at')::timestamptz end,
    left(coalesce(p_order->>'instagram_handle',''),120),
    left(coalesce(p_order->>'order_note',''),1000),
    coalesce((p_order->>'entered_by_admin')::boolean,false),
    case when coalesce(p_order->>'payment_status','paid') in ('paid','unpaid','partial')
         then coalesce(p_order->>'payment_status','paid') else 'paid' end
  )
  on conflict(id) do nothing;

  if not exists(select 1 from public.orders where id=v_id and source='app') then
    raise exception 'Buyurtma saqlanmadi';
  end if;
  return v_id;
end
$function$
;
CREATE OR REPLACE FUNCTION private.release_save_book_base(p_secret text, p_id uuid, p_data jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_discount integer; v_new_image text; v_new_thumbnail text; v_old_image text; v_old_thumbnail text; v_old_images text[]:='{}'; v_images text[]:='{}'; v_title text;
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
 v_discount:=least(99,greatest(0,coalesce((p_data->>'discount_percent')::integer,0)));
 v_new_image:=coalesce(trim(p_data->>'image_url'),''); v_new_thumbnail:=coalesce(trim(p_data->>'thumbnail_url'),'');
 v_title:=coalesce(nullif(trim(p_data->>'title'),''),'Nomsiz kitob');
 if p_data?'image_urls' and jsonb_typeof(p_data->'image_urls')='array' then
  select coalesce(array_agg(x order by ord),'{}'::text[]) into v_images from (
   select trim(value) x,min(ord) ord from jsonb_array_elements_text(p_data->'image_urls') with ordinality e(value,ord)
   where trim(value)<>'' group by trim(value) order by min(ord) limit 20) q;
  v_new_image:=coalesce(v_images[1],'');
 elsif v_new_image<>'' then v_images:=array[v_new_image]; end if;
 if p_id is null then
  if exists(select 1 from public.books b where public.normalize_book_title(b.title)=public.normalize_book_title(v_title)) then raise exception 'Bu nomdagi kitob allaqachon mavjud'; end if;
  insert into public.books(title,author,publisher,category,description,page_count,price,stock,discount_percent,image_url,thumbnail_url,image_urls,is_active,recommended,preorder_enabled,preorder_arrival_note,preorder_deposit_min,preorder_deposit_max,cover,old_price,cost_price,telegram_photo_id)
  values(v_title,coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),btrim(regexp_replace(coalesce(p_data->>'publisher',''),'\s+',' ','g')),
   coalesce(nullif(trim(p_data->>'category'),''),'Boshqalar'),coalesce(nullif(trim(p_data->>'description'),''),'Ma’lumot kiritilmagan.'),
   greatest(0,coalesce((p_data->>'page_count')::integer,0)),
   greatest(0,coalesce((p_data->>'price')::integer,0)),greatest(0,coalesce((p_data->>'stock')::integer,0)),v_discount,
   v_new_image,v_new_thumbnail,v_images,coalesce((p_data->>'is_active')::boolean,true),coalesce((p_data->>'recommended')::boolean,false),
   coalesce((p_data->>'preorder_enabled')::boolean,false),left(coalesce(trim(p_data->>'preorder_arrival_note'),''),160),
   greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)),
   greatest(greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)),coalesce((p_data->>'preorder_deposit_max')::integer,10000)),
   coalesce(nullif(trim(p_data->>'cover'),''),'Ko‘rsatilmagan'),greatest(0,coalesce((p_data->>'old_price')::integer,0)),
   greatest(0,coalesce((p_data->>'cost_price')::integer,0)),'') returning id into v_id;
 else
  select image_url,thumbnail_url,image_urls into v_old_image,v_old_thumbnail,v_old_images from public.books where id=p_id;
  if not(p_data?'image_urls') then
   if v_new_image=coalesce(v_old_image,'') then v_images:=coalesce(v_old_images,'{}');
   elsif v_new_image<>'' then v_images:=array[v_new_image]||coalesce(v_old_images[2:20],'{}'); else v_images:=coalesce(v_old_images[2:20],'{}'); end if;
  end if;
  v_new_image:=coalesce(v_images[1],'');
  if not(p_data?'thumbnail_url') then v_new_thumbnail:=coalesce(v_old_thumbnail,''); end if;
  if coalesce(v_old_image,'') is distinct from v_new_image and not(p_data?'thumbnail_url') then v_new_thumbnail:=''; end if;
  update public.books set title=v_title,author=coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),
   publisher=case when p_data?'publisher' then btrim(regexp_replace(coalesce(p_data->>'publisher',''),'\s+',' ','g')) else publisher end,
   category=coalesce(nullif(trim(p_data->>'category'),''),'Boshqalar'),description=coalesce(nullif(trim(p_data->>'description'),''),'Ma’lumot kiritilmagan.'),
   page_count=case when p_data?'page_count' then greatest(0,coalesce((p_data->>'page_count')::integer,0)) else page_count end,
   price=greatest(0,coalesce((p_data->>'price')::integer,price)),stock=greatest(0,coalesce((p_data->>'stock')::integer,stock)),
   discount_percent=v_discount,image_urls=v_images,image_url=v_new_image,thumbnail_url=v_new_thumbnail,
   telegram_photo_id=case when coalesce(v_old_image,'') is distinct from v_new_image then '' else telegram_photo_id end,
   is_active=coalesce((p_data->>'is_active')::boolean,is_active),recommended=coalesce((p_data->>'recommended')::boolean,recommended),
   preorder_enabled=coalesce((p_data->>'preorder_enabled')::boolean,preorder_enabled),
   preorder_arrival_note=case when p_data?'preorder_arrival_note' then left(coalesce(trim(p_data->>'preorder_arrival_note'),''),160) else preorder_arrival_note end,
   preorder_deposit_min=case when p_data?'preorder_deposit_min' then greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)) else preorder_deposit_min end,
   preorder_deposit_max=case when p_data?'preorder_deposit_max' then greatest(case when p_data?'preorder_deposit_min' then greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)) else preorder_deposit_min end,coalesce((p_data->>'preorder_deposit_max')::integer,10000)) else preorder_deposit_max end,
   cover=coalesce(nullif(trim(p_data->>'cover'),''),cover),old_price=greatest(0,coalesce((p_data->>'old_price')::integer,old_price)),
   cost_price=greatest(0,coalesce((p_data->>'cost_price')::integer,cost_price))
  where id=p_id returning id into v_id;
  if v_id is null then raise exception 'Kitob topilmadi'; end if;
 end if; return v_id;
end $function$
;
revoke all on function private.release_save_book_base(text,uuid,jsonb) from public,anon,authenticated;

create unique index if not exists books_release_title_unique on public.books ((regexp_replace(public.normalize_book_title(title),'\s+',' ','g')));
create table if not exists private.release_book_requests(request_id uuid primary key,book_id uuid not null);
revoke all on private.release_book_requests from public,anon,authenticated;
alter table private.release_book_requests enable row level security;
create or replace function public.admin_save_book(p_secret text,p_id uuid,p_data jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare b public.books%rowtype; saved uuid; request_id uuid; data jsonb:=p_data;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 if p_id is null and p_data?'request_id' then
  request_id:=(p_data->>'request_id')::uuid;
  perform pg_advisory_xact_lock(hashtextextended('book-save:'||request_id::text,0));
  select book_id into saved from private.release_book_requests r where r.request_id=admin_save_book.request_id;
  if saved is not null then return saved; end if;
 end if;
 if p_id is not null then
  select * into b from public.books where id=p_id for update;
  if not found then raise exception 'Kitob topilmadi'; end if;
  if data?'expected_stock' then
   if (data->>'expected_stock')::integer<>b.stock then raise exception 'Ombor o‘zgargan. Kitobni yangilab qayta saqlang'; end if;
  else data:=data-'stock'; end if;
 end if;
 saved:=private.release_save_book_base(p_secret,p_id,data);
 update public.books set planned=coalesce((data->>'planned')::boolean,planned),
  preorder_price_max=case when data?'preorder_price_max' then greatest(0,(data->>'preorder_price_max')::integer) else preorder_price_max end
  where id=saved;
 if request_id is not null then insert into private.release_book_requests values(request_id,saved); end if;
 return saved;
end $$;

create table if not exists private.release_checkout_quotes (
 id uuid primary key default gen_random_uuid(), phone_key text not null, snapshot jsonb not null,
 expires_at timestamptz not null default now()+interval '30 minutes', created_at timestamptz not null default now()
);
create table if not exists private.release_order_owners(order_id uuid primary key,phone_key text not null,quote_id uuid);
create table if not exists private.release_professional_sessions(token uuid primary key default gen_random_uuid(),expires_at timestamptz not null default now()+interval '15 minutes');
create table if not exists private.release_admin_orders(order_id uuid primary key);
create table if not exists private.release_receipt_claims(path text primary key,phone_key text not null,created_at timestamptz not null default now());

create or replace function public.customer_release_receipt(p_session text,p_path text) returns boolean
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); owner text;
begin
 if k is null then raise exception 'PIN bilan kiring'; end if;
 if p_path !~ '^receipts/[A-Za-z0-9._/-]+$' or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=p_path) then raise exception 'Chek fayli yuklanmagan'; end if;
 if exists(select 1 from public.orders where payment_proof_path=p_path) or exists(select 1 from public.preorders where payment_proof_path=p_path) or exists(select 1 from public.web_preorder_requests where payment_proof_path=p_path) then
  raise exception 'Bu chek avval ishlatilgan'; end if;
 insert into private.release_receipt_claims(path,phone_key) values(p_path,k) on conflict do nothing;
 select phone_key into owner from private.release_receipt_claims where path=p_path;
 if owner<>k then raise exception 'Chek boshqa profilga tegishli'; end if;
 return true;
end $$;

create or replace function public.customer_release_professional_login(p_code text) returns uuid
language plpgsql security definer set search_path='' as $$
declare token uuid;
begin
 if not coalesce(public.admin_verify(p_code),false) then raise exception 'Admin kirishi tasdiqlanmadi'; end if;
 insert into private.release_professional_sessions default values returning release_professional_sessions.token into token;
 return token;
end $$;

create or replace function public.customer_release_quote(p_session text,p_order jsonb,p_admin_token uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); o public.orders%rowtype; qid uuid; professional boolean;
begin
 professional:=exists(select 1 from private.release_professional_sessions where token=p_admin_token and expires_at>now());
 if not professional and k is null then raise exception 'PIN bilan kiring'; end if;
 if not professional and public._customer_phone_key(p_order->>'phone')<>k then raise exception 'Profil telefonini ishlating'; end if;
 o:=jsonb_populate_record(null::public.orders,p_order||jsonb_build_object('source','app','status','new','entered_by_admin',professional));
 o:=private.release_prepare_order(o); o:=private.release_finalize_order(o);
 if professional and p_order?'manual_subtotal' then
  if (p_order->>'manual_subtotal')::integer not between 1 and 100000000 then raise exception 'Jami narx noto‘g‘ri'; end if;
  -- Manual orders still use trusted item quantities; manual price is explicit.
  o.subtotal:=(p_order->>'manual_subtotal')::integer; o.total:=o.subtotal+o.delivery_fee;
 end if;
 insert into private.release_checkout_quotes(phone_key,snapshot) values(coalesce(k,'admin:'||p_admin_token::text),to_jsonb(o)) returning id into qid;
 return to_jsonb(o)||jsonb_build_object('quote_id',qid,'expires_at',now()+interval '30 minutes');
end $$;

create or replace function public.customer_release_order(p_session text,p_quote_id uuid,p_order jsonb,p_admin_token uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); q private.release_checkout_quotes%rowtype; o public.orders%rowtype; oid uuid:=(p_order->>'id')::uuid; professional boolean; receipt_path text;
begin
 professional:=exists(select 1 from private.release_professional_sessions where token=p_admin_token and expires_at>now());
 if not professional and k is null then raise exception 'PIN bilan kiring'; end if;
 k:=coalesce(k,'admin:'||p_admin_token::text);
 perform pg_advisory_xact_lock(hashtextextended('checkout:'||oid::text,27));
 if exists(select 1 from private.release_order_owners where order_id=oid and phone_key=k) then
  select * into o from public.orders where id=oid; return to_jsonb(o);
 end if;
 if exists(select 1 from public.orders where id=oid) then raise exception 'Bu buyurtma IDsi boshqa profilga tegishli'; end if;
 select * into q from private.release_checkout_quotes where id=p_quote_id and phone_key=k for update;
 if not found or q.expires_at<=now() then raise exception 'Hisob muddati tugadi. Summani qayta tekshiring'; end if;
 o:=jsonb_populate_record(null::public.orders,q.snapshot);
 if not professional and public._customer_phone_key(o.phone)<>k then raise exception 'Telefon mos emas'; end if;
 receipt_path:=coalesce(p_order->>'payment_proof_path','');
 if not professional and not exists(select 1 from private.release_receipt_claims where release_receipt_claims.path=receipt_path and phone_key=k) then raise exception 'Chek profilingizga biriktirilmagan'; end if;
 if receipt_path<>'' and (exists(select 1 from public.orders where payment_proof_path=receipt_path) or exists(select 1 from public.preorders where payment_proof_path=receipt_path) or exists(select 1 from public.web_preorder_requests where payment_proof_path=receipt_path)) then raise exception 'Bu chek boshqa zakasda ishlatilgan'; end if;
 insert into private.release_order_owners values(oid,k,p_quote_id);
 if professional then insert into private.release_admin_orders values(oid); end if;
 insert into public.orders(id,customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,status,source,items,bundle_selections,payment_proof_path,payment_submitted_at,instagram_handle,order_note,entered_by_admin,payment_status)
 values(oid,o.customer_name,o.phone,o.address,o.delivery_type,o.delivery_fee,o.subtotal,o.total,'new','app',o.items,o.bundle_selections,receipt_path,case when receipt_path='' then null else now() end,o.instagram_handle,o.order_note,professional,case when professional then coalesce(o.payment_status,'paid') else 'paid' end)
 returning * into o;
 return to_jsonb(o);
end $$;

-- Runs after pricing finalization but BEFORE inventory is deducted.
create or replace function private.release_order_final_check() returns trigger
language plpgsql security definer set search_path='' as $$
declare snapshot jsonb;
begin
 if exists(select 1 from private.release_conversion_orders where order_id=new.id) then return new; end if;
 if new.entered_by_admin and not exists(select 1 from private.release_admin_orders where order_id=new.id) then raise exception 'Admin vakolati tasdiqlanmadi'; end if;
 select q.snapshot into snapshot from private.release_order_owners o join private.release_checkout_quotes q on q.id=o.quote_id where o.order_id=new.id;
 if snapshot is not null then
  if new.entered_by_admin then new.subtotal:=(snapshot->>'subtotal')::integer;new.total:=new.subtotal+new.delivery_fee; end if;
  if new.total<>(snapshot->>'total')::integer or new.subtotal<>(snapshot->>'subtotal')::integer or new.items<>snapshot->'items' or new.bundle_selections<>snapshot->'bundle_selections' then
   raise exception 'Narx yoki set o‘zgardi. Yangi hisobni tasdiqlang; ortiqcha pul bo‘lsa admin bilan kelishing'; end if;
 end if;
 return new;
end $$;
drop trigger if exists zzz_orders_release_final_check on public.orders;
create trigger zzz_orders_release_final_check before insert on public.orders for each row execute function private.release_order_final_check();

create or replace function public.require_app_payment_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from private.release_conversion_orders where order_id=new.id) then return new; end if;
 if coalesce(new.source,'app')='app' and not (new.entered_by_admin and exists(select 1 from private.release_admin_orders where order_id=new.id)) then
  if coalesce(new.payment_proof_path,'') !~ '^receipts/[A-Za-z0-9._/-]+$' or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=new.payment_proof_path) then raise exception 'Haqiqiy to‘lov cheki majburiy'; end if;
 end if;
 return new;
end $$;

-- A shared, authenticated inbox. The legacy phone-only endpoint is global only.
create or replace function public.customer_push_history(p_limit integer default 50,p_phone text default '')
returns table(id uuid,title text,body text,sent_at timestamptz,kind text,order_number bigint,order_id uuid)
language sql security definer set search_path='' as $$
 select m.id,m.title,m.body,m.sent_at,'global'::text,null::bigint,null::uuid from public.push_messages m where m.sent_at is not null and length(trim(coalesce(m.body,'')))>=3 order by m.sent_at desc limit least(greatest(coalesce(p_limit,50),1),100)
$$;
create or replace function public.customer_release_inbox(p_session text,p_limit integer default 100)
returns table(id uuid,title text,body text,sent_at timestamptz,kind text,order_number bigint,order_id uuid)
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session);
begin
 if k is null then raise exception 'PIN bilan kiring'; end if;
 return query with combined as (
 select m.id,m.title,m.body,m.sent_at,'global'::text,null::bigint,null::uuid from public.push_messages m where m.sent_at is not null
 union all select m.id,m.title,m.body,m.sent_at,m.kind,m.order_number,m.order_id from public.customer_push_messages m where public._customer_phone_key(m.phone)=k
 ) select * from combined order by 4 desc limit least(greatest(p_limit,1),100);
end $$;

create or replace function public.customer_release_apns(p_session text,p_token text,p_install_id text,p_enabled boolean default true) returns boolean
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session);
begin
 if k is null or not exists(select 1 from private.customer_pin_devices where phone_key=k and install_id=p_install_id) then raise exception 'PIN bilan kiring'; end if;
 if not p_enabled then update private.customer_apns_devices set opted_in=false where install_id=p_install_id and public._customer_phone_key(phone_digits)=k; return true; end if;
 return public.customer_register_native_apns(p_token,(select display_phone from private.customer_pin_profiles where phone_key=k),p_install_id);
end $$;

create table if not exists private.release_pin_recovery (
 id uuid primary key default gen_random_uuid(),phone_key text not null,full_name text not null,note text not null,
 status text not null default 'pending' check(status in ('pending','resolved','rejected')),created_at timestamptz not null default now(),resolved_at timestamptz
);
create unique index if not exists release_one_pending_pin_recovery on private.release_pin_recovery(phone_key) where status='pending';
create or replace function public.customer_release_recover_pin(p_phone text,p_name text,p_note text) returns uuid
language plpgsql security definer set search_path='' as $$
declare k text:=public._customer_phone_key(p_phone); rid uuid;
begin
 if k='' or length(trim(p_name)) not between 2 and 80 or length(trim(p_note)) not between 10 and 500 then raise exception 'Ism, telefon va bog‘lanish ma’lumotini kiriting'; end if;
 insert into private.release_pin_recovery(phone_key,full_name,note) values(k,trim(p_name),trim(p_note))
 on conflict(phone_key) where status='pending' do update set phone_key=excluded.phone_key returning id into rid;
 -- Do not reveal whether the phone has an existing account.
 return rid;
end $$;
create or replace function public.admin_release_recover_pin(p_secret text,p_action text,p_id uuid default null,p_pin text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare r private.release_pin_recovery%rowtype; result jsonb;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='list' then select coalesce(jsonb_agg(to_jsonb(t) order by created_at desc),'[]') into result from (select * from private.release_pin_recovery where status='pending' order by created_at desc limit 200)t;return result; end if;
 select * into r from private.release_pin_recovery where id=p_id for update;
 if not found or r.status<>'pending' then raise exception 'Faol so‘rov topilmadi'; end if;
 if p_action='reset' then
  if p_pin !~ '^[0-9]{4}$' then raise exception 'Yangi vaqtinchalik PIN 4 raqam bo‘lsin'; end if;
  if not exists(select 1 from private.customer_pin_profiles where phone_key=r.phone_key) then raise exception 'Profil topilmadi; so‘rovni rad eting'; end if;
  update private.customer_pin_profiles set pin_hash=extensions.crypt(p_pin,extensions.gen_salt('bf',10)),failed_attempts=0,locked_until=null where phone_key=r.phone_key;
  delete from private.customer_pin_sessions where phone_key=r.phone_key;
  update private.customer_apns_devices set opted_in=false where public._customer_phone_key(phone_digits)=r.phone_key;
  update private.release_pin_recovery set status='resolved',resolved_at=now() where id=p_id;
 elsif p_action='reject' then update private.release_pin_recovery set status='rejected',resolved_at=now() where id=p_id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.customer_release_delete_profile(p_session text,p_pin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); profile private.customer_pin_profiles%rowtype;
begin
 if k is null then raise exception 'PIN bilan qayta kiring'; end if;
 select * into profile from private.customer_pin_profiles where phone_key=k for update;
 if profile.locked_until>now() then raise exception 'PIN vaqtincha bloklangan'; end if;
 if p_pin !~ '^[0-9]{4}$' or extensions.crypt(p_pin,profile.pin_hash)<>profile.pin_hash then
  update private.customer_pin_profiles set failed_attempts=failed_attempts+1,locked_until=case when failed_attempts>=4 then now()+interval '15 minutes' else locked_until end where phone_key=k;
  return jsonb_build_object('deleted',false,'error','PIN noto‘g‘ri');
 end if;
 delete from private.customer_pin_sessions where phone_key=k;
 delete from private.customer_pin_devices where phone_key=k;
 delete from private.customer_pin_profiles where phone_key=k;
 update private.customer_apns_devices set opted_in=false where public._customer_phone_key(phone_digits)=k;
 delete from private.release_receipt_claims where phone_key=k;
 return jsonb_build_object('deleted',true,'retained','Moliyaviy va yetkazish uchun zarur buyurtma yozuvlari saqlanadi');
end $$;

create table if not exists private.release_review_reports (
 id uuid primary key default gen_random_uuid(),review_id uuid not null references public.book_reviews(id),phone_key text not null,
 reason text not null,status text not null default 'pending',created_at timestamptz not null default now(),unique(review_id,phone_key)
);
create table if not exists private.release_review_blocks(phone_key text not null,author_key text not null,created_at timestamptz not null default now(),primary key(phone_key,author_key));
create or replace function public.customer_release_reviews(p_book_id uuid,p_session text default '') returns jsonb
language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'book_id',r.book_id,'reviewer_name',r.reviewer_name,'rating',r.rating,'comment',r.comment,'created_at',r.created_at) order by r.created_at desc),'[]')
 from public.book_reviews r join public.orders o on o.id=r.order_id where r.book_id=p_book_id and r.is_approved and not exists(
 select 1 from private.release_review_blocks b where b.phone_key=private.pin_session_phone(p_session) and b.author_key=public._customer_phone_key(o.phone))
$$;
create or replace function public.customer_release_review_action(p_session text,p_review_id uuid,p_action text,p_reason text default '') returns boolean
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); author text;
begin
 if k is null then raise exception 'PIN bilan kiring'; end if;
 select public._customer_phone_key(o.phone) into author from public.book_reviews r join public.orders o on o.id=r.order_id where r.id=p_review_id;
 if author is null then raise exception 'Sharh topilmadi'; end if;
 if p_action='report' then
  if length(trim(p_reason)) not between 3 and 500 then raise exception 'Shikoyat sababini kiriting'; end if;
  insert into private.release_review_reports(review_id,phone_key,reason) values(p_review_id,k,trim(p_reason)) on conflict(review_id,phone_key) do update set reason=excluded.reason,status='pending';
 elsif p_action='block' then insert into private.release_review_blocks values(k,author,now()) on conflict do nothing;
 elsif p_action='unblock_all' then delete from private.release_review_blocks where phone_key=k;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return true;
end $$;
create or replace function public.admin_release_review_reports(p_secret text,p_action text default 'list',p_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; rid uuid;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(t) order by created_at desc),'[]') into result from (
   select a.id,a.review_id,a.reason,a.created_at,r.reviewer_name,r.comment,r.is_approved from private.release_review_reports a join public.book_reviews r on r.id=a.review_id where a.status='pending' limit 200)t;
  return result;
 end if;
 select review_id into rid from private.release_review_reports where id=p_id for update;
 if rid is null then raise exception 'Shikoyat topilmadi'; end if;
 if p_action='hide' then update public.book_reviews set is_approved=false,updated_at=now() where id=rid;
 elsif p_action='dismiss' then null;
 else raise exception 'Amal noto‘g‘ri'; end if;
 update private.release_review_reports set status=p_action where review_id=rid;
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_release_today_revenue(p_secret text) returns bigint
language plpgsql security definer set search_path='' as $$
declare value bigint;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 select coalesce(sum(coalesce(p.unit_price,s.unit_price)),0) into value from public.sales_log s left join private.book_sale_profit_snapshots p on p.order_id=s.order_id and p.item_index=s.item_index and p.unit_index=s.unit_index
 where (coalesce(p.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date=(now() at time zone 'Asia/Seoul')::date;
 -- Matches the finance ledger: book revenue, excluding delivery charges.
 return value;
end $$;

-- A zero balance does not require a fictitious receipt. Admin verifies the advance.
-- Lock the source rows before cancellation and never discard old receipts.
do $$ declare r record; begin
 for r in select id from public.web_preorder_requests where status='cancelled' loop
  perform private.release_cancel_preorder('web',r.id::text);
 end loop;
end $$;

-- Private state is accessible only through the narrow SECURITY DEFINER APIs.
do $$ declare r record; begin
 for r in select tablename from pg_tables where schemaname='private' and tablename like 'release_%' loop
  execute format('alter table private.%I enable row level security',r.tablename);
  execute format('revoke all on private.%I from public,anon,authenticated',r.tablename);
 end loop;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
  (n.nspname='private' and p.proname like 'release_%') or (n.nspname='public' and (p.proname like 'customer_release_%' or p.proname like 'admin_release_%')) loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
  execute format('grant execute on function %s to service_role',r.sig);
 end loop;
end $$;
notify pgrst,'reload schema';

-- Keep old clients from modifying a migrated ledger through legacy writers.
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
 if exists(select 1 from private.release_preorder_invoices where source='native' and reference=p_preorder_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

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
$function$

;
CREATE OR REPLACE FUNCTION public.customer_preorder_balance_proof(p_install_id text, p_preorder_id bigint, p_path text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.preorders%rowtype; r private.preorder_payment_requests%rowtype;
begin
 if exists(select 1 from private.release_preorder_invoices where source='native' and reference=p_preorder_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

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
$function$

;
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
 if exists(select 1 from private.release_preorder_invoices where source='web' and reference=p_preorder_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

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
$function$

;
CREATE OR REPLACE FUNCTION public.customer_web_preorder_delivery(p_session text, p_preorder_id uuid, p_recipient_name text, p_recipient_phone text, p_address text, p_delivery_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  original public.web_preorder_requests%rowtype;
  old private.web_preorder_checkout%rowtype;
  checked jsonb;
  digits text:=regexp_replace(coalesce(p_recipient_phone,''),'[^0-9]','','g');
  cname text:=btrim(coalesce(p_recipient_name,''));
  destination text:=btrim(coalesce(p_address,''));
  qty_extra integer;
  ship integer;
  base_sum bigint;
begin
 if exists(select 1 from private.release_preorder_invoices where source='web' and reference=p_preorder_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

  -- Existing checkout validates PIN session AND ownership of original order,
  -- including linked device and customer PIN profile. No public phone lookup.
  checked:=public.customer_web_preorder_checkout(
    p_session,p_preorder_id,'detail',null,0,null);
  if checked->>'status' <> 'arrived' or (checked->>'price_ready')::boolean is not true then
    raise exception 'Kitob kelmagan yoki yakuniy narx hali tasdiqlanmagan';
  end if;
  if p_delivery_type not in ('택배','경산 직접수령','경산 무료배송') or
     length(cname) not between 2 and 80 or digits !~ '^010[0-9]{8}$' or
     (p_delivery_type in ('택배','경산 무료배송') and length(destination) not between 8 and 500) or
     length(destination)>500 then
    raise exception 'Ism, telefon, manzil va yetkazish usulini tekshiring';
  end if;
  if p_delivery_type='경산 무료배송' and
     destination !~ '경산' and lower(destination) !~ 'gyeongsan' then
    raise exception 'Gyeongsan ichiga bepul yetkazish uchun 경산시 manzilini kiriting';
  end if;
  select * into original from public.web_preorder_requests
    where id=p_preorder_id for update;
  select * into old from private.web_preorder_checkout
    where preorder_id=p_preorder_id for update;
  if not found or original.status<>'arrived' then
    raise exception 'Zakaz yopiq yoki to‘lov hisobi mavjud emas'; end if;
  select coalesce(sum(quantity),0)::integer into qty_extra
    from private.web_preorder_checkout_items where preorder_id=p_preorder_id;
  ship:=case when p_delivery_type in ('경산 직접수령','경산 무료배송') then 0
       when original.quantity+qty_extra>=4 and not exists(
         select 1 from public.books promo where promo.discount_percent>0
           and (promo.discount_ends_at is null or promo.discount_ends_at>now())
           and promo.discount_free_delivery=false
       ) then 0 else 4000 end;
  -- Never change the original payment proof. A free delivery choice after
  -- submitting a postal payment creates an admin-visible pending refund.
  -- Do not let a customer add a higher shipping charge to a frozen payment.
  base_sum:=original.quantity::bigint*old.unit_price+ship;
  if old.payment_state<>'requested' and
    greatest(base_sum+old.extra_total-old.deposit_credit,0)>
      coalesce(old.proof_submitted_amount,old.amount_due) then
    raise exception 'Eski chek bu yetkazish narxini qoplamaydi. O‘zgartirish uchun admin bilan bog‘laning';
  end if;
  update private.web_preorder_checkout set
    recipient_name=cname,
    recipient_phone=digits,
    delivery_address=case when p_delivery_type='경산 직접수령'
       then '경산 직접수령' else destination end,
    delivery_type=p_delivery_type,
    delivery_saved=true,
    shipping_fee=ship,
    base_total=base_sum,
    amount_due=greatest(base_sum+extra_total-deposit_credit,0),
    shipping_refund_due=case when old.payment_state='requested' then 0
      else greatest(coalesce(old.proof_submitted_amount,old.amount_due)
        -greatest(base_sum+old.extra_total-old.deposit_credit,0),0) end,
    updated_at=now()
  where preorder_id=p_preorder_id;
  -- Return authoritative server arithmetic, not client-calculated totals.
  return public.customer_web_preorder_checkout(
    p_session,p_preorder_id,'detail',null,0,null);
end;
$function$

;
CREATE OR REPLACE FUNCTION public.admin_native_preorder_arrive_invoice(p_secret text, p_id bigint, p_expected_status text, p_unit_price integer, p_shipping_fee integer, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.preorders%rowtype; v_note text:=trim(coalesce(p_note,''));
        v_total bigint; v_due bigint; v_hold integer;
begin
 if exists(select 1 from private.release_preorder_invoices where source='native' and reference=p_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

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
$function$

;
CREATE OR REPLACE FUNCTION public.admin_web_preorder_checkout_confirm(p_secret text, p_preorder_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.web_preorder_requests%rowtype; inv private.web_preorder_checkout%rowtype;
begin
 if exists(select 1 from private.release_preorder_invoices where source='web' and reference=p_preorder_id::text) then raise exception 'Yangilangan oldindan zakas panelidan foydalaning'; end if;

 if public._admin_secret_ok(p_secret) is not true then raise exception 'Admin ruxsati yo‘q'; end if;
 select * into v from public.web_preorder_requests where id=p_preorder_id for update;
 if not found or v.status<>'arrived' then raise exception 'Zakaz topilmadi yoki kelmagan'; end if;
 select * into inv from private.web_preorder_checkout where preorder_id=v.id for update;
 if not found then raise exception 'To‘lov hisobi mavjud emas'; end if;
 if inv.payment_state='verified' then
   return jsonb_build_object('payment_state','verified','duplicate',true); end if;
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
$function$

;
CREATE OR REPLACE FUNCTION public.customer_preorder_submit(p_install_id text, p_book_id uuid, p_customer_name text DEFAULT ''::text, p_phone text DEFAULT ''::text, p_quantity integer DEFAULT 1, p_deposit_amount integer DEFAULT 0, p_payment_proof_path text DEFAULT ''::text, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.preorders; prior public.preorders%rowtype; v_min integer; v_max integer; safe_install text:=trim(p_install_id);
begin
  if length(trim(p_install_id))<12 or p_quantity is null or p_quantity<1 or p_quantity>20 then raise exception 'Invalid preorder'; end if;
  select preorder_deposit_min,preorder_deposit_max into v_min,v_max
  from public.books where id=p_book_id and is_active=true and preorder_enabled=true;
  if not found then raise exception 'Oldindan sotuv yopiq'; end if;
  if p_deposit_amount is null or p_deposit_amount < v_min*p_quantity or p_deposit_amount > v_max*p_quantity then
    raise exception 'Jami avans %–% won bo‘lishi kerak',v_min*p_quantity,v_max*p_quantity;
  end if;
  if trim(coalesce(p_payment_proof_path,''))='' then raise exception 'To‘lov cheki kerak'; end if;
  if not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=p_payment_proof_path) or not exists(
   select 1 from private.release_receipt_claims c join private.customer_pin_devices d on d.phone_key=c.phone_key
   where c.path=p_payment_proof_path and c.phone_key=public._customer_phone_key(p_phone) and d.install_id=p_install_id
  ) then raise exception 'Avans cheki PIN profilingizga biriktirilmagan'; end if;
  if exists(select 1 from public.preorders where payment_proof_path=p_payment_proof_path and install_id<>p_install_id) or
   exists(select 1 from public.orders where payment_proof_path=p_payment_proof_path) then raise exception 'Chek boshqa buyurtmada ishlatilgan'; end if;
  -- A cancelled request is historical and never blocks a fresh booking.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('preorder:'||safe_install||':'||p_book_id::text,0));
  select * into prior from public.preorders
    where book_id=p_book_id and install_id=safe_install
      and status in ('waiting','contacted','accepted','arrived')
    order by id desc limit 1 for update;
  if found then
    if prior.status='waiting'
      and prior.payment_proof_path=left(trim(p_payment_proof_path),500)
      and prior.deposit_amount=p_deposit_amount and prior.quantity=p_quantity
      and prior.phone=left(trim(p_phone),32)
      and prior.customer_name=left(trim(p_customer_name),80)
      and coalesce(prior.note,'')=left(trim(coalesce(p_note,'')),500) then
      return jsonb_build_object('id',prior.id,'status',prior.status,
        'deposit_amount',prior.deposit_amount,'duplicate',true);
    end if;
    raise exception 'Bu kitobga faol zakazingiz bor. Oldindan zakazlarim bo‘limini tekshiring. Bekor qilingach qayta zakaz berish mumkin.';
  end if;
  insert into public.preorders(book_id,install_id,customer_name,phone,quantity,status,deposit_amount,payment_proof_path,note)
  values(p_book_id,safe_install,left(trim(p_customer_name),80),left(trim(p_phone),32),p_quantity,'waiting',
         p_deposit_amount,left(trim(p_payment_proof_path),500),left(trim(p_note),500))
  returning * into r;
  return jsonb_build_object('id',r.id,'status',r.status,'deposit_amount',r.deposit_amount,'duplicate',false);
exception when unique_violation then
  raise exception 'Bu kitob uchun faol oldindan zakaz bor. Oldindan zakazlarim bo‘limini tekshiring.';
end $function$

;
CREATE OR REPLACE FUNCTION public.web_preorder_submit(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 c jsonb; old public.web_preorder_requests%rowtype;
 rid uuid := (p_request->>'id')::uuid;
 bid uuid := nullif(p_request->>'book_id','')::uuid;
 qty integer := (p_request->>'quantity')::integer;
 title text := trim(p_request->>'book_title'); cname text := trim(p_request->>'customer_name');
 phone text := regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
 book_path text := coalesce(p_request->>'book_image_path','');
 proof_path text := p_request->>'payment_proof_path';
 total integer := (p_request->>'deposit_amount')::integer; per_book integer;
begin
 if private.pin_session_phone(p_request->>'session') is null or private.pin_session_phone(p_request->>'session')<>public._customer_phone_key(p_request->>'phone') or
  not exists(select 1 from private.customer_pin_devices d where d.phone_key=private.pin_session_phone(p_request->>'session') and d.install_id=p_request->>'install_id') then raise exception 'PIN profiliga kiring va profil telefonini ishlating'; end if;

 if nullif(trim(coalesce(p_request->>'install_id','')),'') is not null and
    length(trim(p_request->>'install_id')) not between 12 and 120 then
    raise exception 'Qurilma identifikatori noto‘g‘ri'; end if;
 if rid is null or qty is null or qty not between 1 and 20 or
   coalesce(length(cname),0) not between 2 and 80 or phone !~ '^010[0-9]{8}$' then
   raise exception 'Ism, telefon va miqdorni tekshiring.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
 select * into old from public.web_preorder_requests r where r.id=rid;
 if found then
   if old.status='cancelled' then
     raise exception 'Bu bekor qilingan eski zakaz. Yangi buyurtma uchun yangi zakaz sahifasini oching. Eski avans avtomatik ko‘chirilmaydi.';
   end if;
   if old.phone is distinct from phone or old.quantity is distinct from qty or
     old.customer_name is distinct from cname or old.book_id is distinct from bid or
     (bid is null and (old.book_title is distinct from title or old.book_image_path is distinct from book_path)) or
     old.payment_proof_path is distinct from proof_path or old.deposit_amount is distinct from total then
     raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.'; end if;
   return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
 end if;
 if bid is null then
   perform 1 from public.web_preorder_settings where id for share;
   c:=public.web_preorder_config();
 else
   perform 1 from public.books where id=bid for share;
   c:=public.web_preorder_book_config(bid);
   title:=c->>'book_title'; book_path:='';
 end if;
 if c is null or (c->>'enabled')::boolean is not true or trim(coalesce(c->>'arrival_note',''))='' then
   raise exception 'Bu kitob uchun oldindan buyurtma qabuli hozircha yopiq. Avans yubormang.'; end if;
 if coalesce(length(title),0) not between 2 and 160 then raise exception 'Kitob nomini tekshiring.'; end if;
 if (bid is null and (p_request->>'revision')::bigint is distinct from (c->>'revision')::bigint) or
    (bid is not null and p_request->>'terms_token' is distinct from c->>'terms_token') then
   raise exception 'Sana yoki avans o‘zgargan. Shartlarni yangilab, qayta tekshiring.'; end if;
 if total is null or total % qty <> 0 then raise exception 'Avans summasini tekshiring.'; end if;
 per_book:=total/qty;
 if per_book not between (c->>'deposit_amount')::integer and coalesce((c->>'deposit_max')::integer,(c->>'deposit_amount')::integer) then
   raise exception 'Avans summasini tekshiring.'; end if;
 if proof_path is null or proof_path !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
    not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof_path) or
    (bid is null and (book_path !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') or
      not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=book_path))) then
   raise exception 'Kitob rasmi va to‘lov chekini yuklang.'; end if;
 insert into public.web_preorder_requests(id,book_id,customer_name,phone,book_title,book_image_path,
  book_image_url,payment_proof_path,quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,terms_token,install_id)
 values(rid,bid,cname,phone,title,book_path,coalesce(c->>'book_image_url',''),proof_path,qty,per_book,total,
  c->>'arrival_note',(c->>'revision')::bigint,coalesce(c->>'terms_token',''),nullif(trim(p_request->>'install_id'),''));
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false);
exception when unique_violation then
 if exists(select 1 from public.web_preorder_requests w
    where substring(w.payment_proof_path from 'proof-([a-f0-9]{64})')=
          substring(proof_path from 'proof-([a-f0-9]{64})')
      and w.status='cancelled') then
    raise exception 'Eski bekor qilingan zakazdagi chekni qayta yubormang. Yangi zakaz uchun yangi avans cheki kerak. Oldingi avansni ko‘chirish uchun admin tasdig‘i talab qilinadi.';
  end if;
  raise exception 'Bu avans cheki boshqa buyurtmada ishlatilgan. Yangi to‘lov chekini yuboring yoki mavjud zakazni tekshiring.';
end;
$function$

;
CREATE OR REPLACE FUNCTION public.web_preorder_submit_multi(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 s public.web_preorder_settings%rowtype; old public.web_preorder_requests%rowtype;
 rid uuid:=(p_request->>'id')::uuid;
 cname text:=trim(p_request->>'customer_name');
 phone_value text:=regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
 proof text:=p_request->>'payment_proof_path';
 total bigint:=(p_request->>'deposit_amount')::bigint;
 item jsonb; normalized jsonb:='[]'; title_value text; image_value text; qty integer;
 units bigint:=0; summary text;
begin
 if private.pin_session_phone(p_request->>'session') is null or private.pin_session_phone(p_request->>'session')<>public._customer_phone_key(p_request->>'phone') or
  not exists(select 1 from private.customer_pin_devices d where d.phone_key=private.pin_session_phone(p_request->>'session') and d.install_id=p_request->>'install_id') then raise exception 'PIN profiliga kiring va profil telefonini ishlating'; end if;

 if nullif(trim(coalesce(p_request->>'install_id','')),'') is not null and
    length(trim(p_request->>'install_id')) not between 12 and 120 then
    raise exception 'Qurilma identifikatori noto‘g‘ri'; end if;
 if rid is null or coalesce(length(cname),0) not between 2 and 80 or
   phone_value !~ '^010[0-9]{8}$' or jsonb_typeof(p_request->'items') is distinct from 'array' then
   raise exception 'Ism, telefon va kitoblarni tekshiring.'; end if;
 if jsonb_array_length(p_request->'items')=0 then raise exception 'Kamida bitta kitob kiriting.'; end if;
 for item in select value from jsonb_array_elements(p_request->'items') loop
  title_value:=trim(item->>'book_title'); image_value:=item->>'book_image_path'; qty:=(item->>'quantity')::integer;
  if coalesce(length(title_value),0) not between 2 and 160 or qty is null or qty not between 1 and 20 or
   image_value is null or image_value !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') then
   raise exception 'Har bir kitobning nomi, rasmi va miqdorini tekshiring.'; end if;
  units:=units+qty;
  normalized:=normalized||jsonb_build_array(jsonb_build_object('book_title',title_value,'book_image_path',image_value,'quantity',qty));
 end loop;
 if units>100000 or total is null or total>2147483647 then raise exception 'So‘rov juda katta. Kitoblarni alohida so‘rovlarga ajrating.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
 select * into old from public.web_preorder_requests r where r.id=rid;
 if found then
   if old.status='cancelled' then
     raise exception 'Bu bekor qilingan eski zakaz. Yangi buyurtma uchun yangi zakaz sahifasini oching. Eski avans avtomatik ko‘chirilmaydi.';
   end if;
  if old.phone is distinct from phone_value or old.customer_name is distinct from cname or
   old.request_items is distinct from normalized or old.payment_proof_path is distinct from proof or
   old.deposit_amount is distinct from total then raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.'; end if;
  return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
 end if;
 select * into s from public.web_preorder_settings where id for share;
 if not s.enabled or trim(s.arrival_note)='' then raise exception 'Oldindan buyurtma qabuli yopiq. Avans yubormang.'; end if;
 if (p_request->>'revision')::bigint is distinct from s.revision or total is distinct from s.deposit_amount::bigint*units then
  raise exception 'Sana yoki avans o‘zgargan. Shartlarni qayta tekshiring.'; end if;
 if proof is null or proof !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
  not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof) or
  exists(select 1 from jsonb_array_elements(normalized) i where not exists
   (select 1 from storage.objects where bucket_id='web-preorder-assets' and name=i->>'book_image_path')) then
  raise exception 'Barcha kitob rasmlari va jami avans chekini yuklang.'; end if;
 summary:=case when jsonb_array_length(normalized)=1 then normalized->0->>'book_title'
  else left(normalized->0->>'book_title',130)||' + '||(jsonb_array_length(normalized)-1)||' turdagi kitob' end;
 insert into public.web_preorder_requests(id,customer_name,phone,book_title,book_image_path,payment_proof_path,
  quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,request_items,install_id)
 values(rid,cname,phone_value,summary,normalized->0->>'book_image_path',proof,units::integer,s.deposit_amount,total::integer,
  s.arrival_note,s.revision,normalized,nullif(trim(p_request->>'install_id'),''));
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false,'item_count',jsonb_array_length(normalized));
exception when unique_violation then
 if exists(select 1 from public.web_preorder_requests w
    where substring(w.payment_proof_path from 'proof-([a-f0-9]{64})')=
          substring(proof from 'proof-([a-f0-9]{64})')
      and w.status='cancelled') then
    raise exception 'Eski bekor qilingan zakazdagi chekni qayta yubormang. Yangi zakaz uchun yangi avans cheki kerak. Oldingi avansni ko‘chirish uchun admin tasdig‘i talab qilinadi.';
  end if;
  raise exception 'Bu avans cheki boshqa buyurtmada ishlatilgan. Yangi to‘lov chekini yuboring yoki mavjud zakazni tekshiring.';
end;
$function$

;

create or replace function public.customer_pin_logout(p_session text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k text:=private.pin_session_phone(p_session); device text;
begin
 select install_id into device from private.customer_pin_sessions where token_hash=encode(extensions.digest(p_session,'sha256'),'hex');
 if k is not null then update private.customer_apns_devices set opted_in=false where install_id=device and public._customer_phone_key(phone_digits)=k; end if;
 delete from private.customer_pin_sessions where token_hash=encode(extensions.digest(p_session,'sha256'),'hex');
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.admin_release_orders(p_secret text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 select coalesce(jsonb_agg(to_jsonb(o)||jsonb_build_object('recognized_sale_at',sale.sold_at) order by o.created_at desc),'[]') into result
 from public.orders o left join lateral (
 select min(coalesce(p.first_sold_at,s.sold_at)) sold_at from public.sales_log s left join private.book_sale_profit_snapshots p on p.order_id=s.order_id and p.item_index=s.item_index and p.unit_index=s.unit_index where s.order_id=o.id
 ) sale on true;
 return result;
end $$;

do $$ declare r record; begin
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
 (n.nspname='private' and p.proname like 'release_%') or (n.nspname='public' and (p.proname like 'customer_release_%' or p.proname like 'admin_release_%')) loop
 execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 execute format('grant execute on function %s to service_role',r.sig);
 end loop;
end $$;
notify pgrst,'reload schema';
