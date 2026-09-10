create or replace function public.bot_mark_instagram_order(p_secret text, p_cloud_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  o public.orders%rowtype;
  rec record;
  v_title text;
  v_stock integer;
begin
  if not public._secret_ok(p_secret, 'ff2c7a6de8f32fb3153d1f01a7e9b171005789f249f364bd5bc6bf2210c6adfd') then
    raise exception 'Ruxsat yo‘q';
  end if;

  select * into o
  from public.orders
  where id = p_cloud_id
  for update;

  if not found then
    raise exception 'Buyurtma topilmadi';
  end if;

  -- Idempotent: avval Instagram qilib bo‘lingan bo‘lsa stockni qayta ayirmaymiz.
  if coalesce(o.source, '') = 'instagram' then
    perform public._rebuild_sales_log_for_order(p_cloud_id);
    return;
  end if;

  if coalesce(o.source, '') <> 'telegram' then
    raise exception 'Bu buyurtmani Instagram savdoga o‘tkazib bo‘lmaydi';
  end if;

  -- Instagram oqimida Telegram chat_id 0 bo‘ladi. Oddiy Telegram buyurtmasini
  -- xato chaqiriq bilan ikkinchi marta ombordan ayirib yubormaymiz.
  if coalesce(o.telegram_chat_id, 0) <> 0 then
    raise exception 'Bu oddiy Telegram buyurtmasi';
  end if;

  if o.status not in ('accepted','paid','shipping') or not coalesce(o.stock_reserved, false) then
    raise exception 'Instagram savdo holati omborni band qilishga tayyor emas';
  end if;

  if jsonb_typeof(o.items) <> 'array' or jsonb_array_length(o.items) = 0 then
    raise exception 'Instagram savdo tarkibi bo‘sh';
  end if;

  -- Hamma kitobni avval FOR UPDATE bilan tekshiramiz. Yetarli bo‘lmasa hech
  -- narsani kamaytirmaymiz va butun tranzaksiya bekor bo‘ladi.
  for rec in
    select (x->>'book_id')::uuid as book_id,
           sum((x->>'quantity')::integer)::integer as qty
    from jsonb_array_elements(o.items) as x
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
      raise exception 'Instagram savdodagi kitob topilmadi yoki faol emas';
    end if;
    if rec.qty <= 0 then
      raise exception 'Instagram savdodagi kitob soni noto‘g‘ri';
    end if;
    if v_stock < rec.qty then
      raise exception '“%” omborda yetarli emas. Hozir % dona bor', v_title, v_stock;
    end if;
  end loop;

  for rec in
    select (x->>'book_id')::uuid as book_id,
           sum((x->>'quantity')::integer)::integer as qty
    from jsonb_array_elements(o.items) as x
    group by (x->>'book_id')::uuid
  loop
    update public.books
       set stock = stock - rec.qty,
           updated_at = now()
     where id = rec.book_id;
  end loop;

  update public.orders
     set source = 'instagram',
         stock_reserved = true,
         stock_restored = false,
         updated_at = now()
   where id = p_cloud_id;

  perform public._rebuild_sales_log_for_order(p_cloud_id);
end;
$function$;
