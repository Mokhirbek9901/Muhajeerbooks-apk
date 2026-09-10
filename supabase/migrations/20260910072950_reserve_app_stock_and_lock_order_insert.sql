create or replace function private.reserve_app_order_stock_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  rec record;
  v_title text;
  v_stock integer;
begin
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
$$;

revoke all on function private.reserve_app_order_stock_on_insert() from public, anon, authenticated;

drop trigger if exists zzz_orders_reserve_app_stock on public.orders;
create trigger zzz_orders_reserve_app_stock
before insert on public.orders
for each row
execute function private.reserve_app_order_stock_on_insert();

drop policy if exists orders_public_insert on public.orders;

drop policy if exists orders_insert_returning_post on public.orders;
create policy orders_insert_returning_post
on public.orders
for select
to anon, authenticated
using (
  coalesce(current_setting('request.method', true), '') = 'POST'
  and source = 'app'
);
