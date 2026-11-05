-- Existing inactive books can have missing historical catalog prices.
-- Updating their price must not activate the book or rewrite any sale.
CREATE OR REPLACE FUNCTION public.admin_profit_lot_price_review(p_secret text, p_lot_id bigint, p_expected_unit_cost integer, p_new_unit_cost integer, p_expected_sale_price integer, p_new_sale_price integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '12s'
AS $function$
declare
  v_lot public.web_book_batches%rowtype;
  v_book public.books%rowtype;
  v_book_id uuid;
  v_effective_price integer;
  v_discount_active boolean;
  v_cost_changed boolean;
  v_price_changed boolean;
begin
  if public.admin_verify(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_lot_id is null or p_expected_unit_cost is null
    or p_new_unit_cost is null or p_expected_sale_price is null
    or p_new_sale_price is null
    or p_lot_id < 1
    or p_expected_unit_cost not between 0 and 100000000
    or p_new_unit_cost not between 0 and 100000000
    or p_expected_sale_price not between 0 and 100000000
    or p_new_sale_price not between 0 and 100000000 then
    raise exception 'Narx yoki partiya identifikatori noto‘g‘ri';
  end if;

  -- Lock book before the lot, and compare both values supplied by UI.
  select book_id into v_book_id
  from public.web_book_batches where id=p_lot_id;
  if v_book_id is null then
    raise exception 'Partiya kitobi topilmadi';
  end if;
  select * into v_book from public.books
    where id=v_book_id for update;
  if not found then
    raise exception 'Katalogdagi kitob topilmadi';
  end if;
  select * into v_lot from public.web_book_batches
    where id=p_lot_id for update;
  if not found or v_lot.book_id is distinct from v_book_id then
    raise exception 'Partiya o‘zgargan. Qayta yuklang';
  end if;
  v_discount_active := v_book.discount_percent > 0 and
    (v_book.discount_ends_at is null or v_book.discount_ends_at > now());
  v_effective_price := case
    when v_discount_active then
      round(v_book.price * (100-v_book.discount_percent) / 100.0)::integer
    else v_book.price end;

  if v_lot.unit_cost <> p_expected_unit_cost
    or v_effective_price <> p_expected_sale_price then
    raise exception 'Narx boshqa joyda o‘zgargan. Hisobotni yangilang';
  end if;

  v_cost_changed := p_new_unit_cost <> v_lot.unit_cost;
  v_price_changed := p_new_sale_price <> v_effective_price;
  if not v_cost_changed and not v_price_changed then
    return jsonb_build_object('saved',true,'unchanged',true,
      'lot_id',v_lot.id,'unit_cost',v_lot.unit_cost,
      'sale_price',v_effective_price);
  end if;

  if v_cost_changed and p_new_unit_cost < 1 then
    raise exception 'Yangi tan narxi ₩1 dan kam bo‘lmasin';
  end if;
  if v_price_changed and p_new_sale_price < 1 then
    raise exception 'Yangi sotuv narxi ₩1 dan kam bo‘lmasin';
  end if;
  if v_price_changed and v_discount_active then
    raise exception 'Kitobda faol chegirma bor. Sotuv narxini katalogda chegirma bilan birga tahrirlang';
  end if;

  if v_cost_changed then
    update public.web_book_batches
      set unit_cost=p_new_unit_cost, cost_origin='manual'
      where id=v_lot.id;
  end if;
  if v_price_changed then
    update public.books
      set price=p_new_sale_price, updated_at=now()
      where id=v_book.id;
  end if;
  insert into private.profit_lot_price_review_audit(
    lot_id,book_id,old_unit_cost,new_unit_cost,
    old_catalog_price,new_catalog_price
  ) values(
    v_lot.id,v_book.id,v_lot.unit_cost,p_new_unit_cost,
    v_book.price,case when v_price_changed
      then p_new_sale_price else v_book.price end
  );
  return jsonb_build_object(
    'saved',true,'unchanged',false,'lot_id',v_lot.id,
    'book_id',v_book.id,'unit_cost',p_new_unit_cost,
    'sale_price',case when v_price_changed
      then p_new_sale_price else v_effective_price end,
    'inventory_changed',false,'past_sales_changed',false,
    'other_lots_changed',false
  );
end;
$function$;
