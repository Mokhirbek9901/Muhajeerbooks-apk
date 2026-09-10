create or replace function private.handle_direct_app_order_status_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item jsonb;
  bid uuid;
  qty integer;
  b public.books%rowtype;
  v_method text := coalesce(current_setting('request.method', true), '');
begin
  -- Flutter web admin panel statusni PostgREST PATCH bilan yangilaydi.
  -- Bot/admin RPC oqimlari POST bo'lib, ular _order_set_status_core orqali boshqariladi.
  if v_method <> 'PATCH' or coalesce(new.source, 'app') <> 'app' or new.status = old.status then
    return new;
  end if;

  if new.status not in ('new', 'accepted', 'paid', 'shipping', 'cancelled') then
    raise exception 'Noto‘g‘ri buyurtma holati';
  end if;
  if old.status = 'cancelled' and new.status <> 'cancelled' then
    raise exception 'Bekor qilingan buyurtmani qayta faollashtirib bo‘lmaydi';
  end if;
  if old.status = 'shipping' and new.status <> 'shipping' then
    raise exception 'Jo‘natilgan buyurtma yakuniy holatda';
  end if;

  if new.status in ('accepted', 'paid', 'shipping') and not old.stock_reserved then
    for item in select * from jsonb_array_elements(old.items)
    loop
      bid := (item->>'book_id')::uuid;
      qty := greatest(coalesce((item->>'quantity')::integer, 0), 0);
      if qty <= 0 then raise exception 'Buyurtma tarkibi noto‘g‘ri'; end if;
      select * into b from public.books where id = bid for update;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi'; end if;
      if b.stock < qty then
        raise exception '“%” uchun omborda % dona kerak, % dona bor', b.title, qty, b.stock;
      end if;
    end loop;
    for item in select * from jsonb_array_elements(old.items)
    loop
      bid := (item->>'book_id')::uuid;
      qty := (item->>'quantity')::integer;
      update public.books set stock = stock - qty where id = bid;
    end loop;
    new.stock_reserved := true;
    new.stock_restored := false;
  end if;

  if new.status = 'cancelled' and old.status <> 'cancelled' then
    if old.stock_reserved and not old.stock_restored then
      for item in select * from jsonb_array_elements(old.items)
      loop
        bid := (item->>'book_id')::uuid;
        qty := greatest(coalesce((item->>'quantity')::integer, 0), 0);
        if qty > 0 then
          update public.books set stock = stock + qty where id = bid;
        end if;
      end loop;
    end if;
    new.stock_reserved := false;
    new.stock_restored := (old.stock_reserved or old.stock_restored);
  end if;

  return new;
end;
$$;

revoke all on function private.handle_direct_app_order_status_update() from public, anon, authenticated;

drop trigger if exists zzzz_orders_direct_app_status_guard on public.orders;
create trigger zzzz_orders_direct_app_status_guard
before update of status on public.orders
for each row
execute function private.handle_direct_app_order_status_update();
