-- Old bot sync data must not resurrect an already-cancelled duplicate order.
-- Any returned unchanged order keeps sales_log and stock correctly reconciled.
CREATE OR REPLACE FUNCTION public.bot_order_sync_upsert(p_secret text, p_order jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  oid bigint;
  existing uuid;
  existing_source text;
  existing_status text;
  mapped_status text;
  items_in jsonb;
  item jsonb;
  safe_items jsonb := '[]'::jsonb;
  tid bigint;
  bid uuid;
  qty integer;
  unit_price integer;
  subtotal integer := 0;
  cnt integer := 0;
  fee integer := 4000;
  created_ts timestamptz;
  cutoff_ts timestamptz;
  cutoff_oid bigint;
begin
  if not public._secret_ok(p_secret, 'ff2c7a6de8f32fb3153d1f01a7e9b171005789f249f364bd5bc6bf2210c6adfd') then raise exception 'Ruxsat yo‘q'; end if;
  oid := nullif(p_order->>'order_id','')::bigint;
  if oid is null then raise exception 'order_id kerak'; end if;

  begin
    created_ts := nullif(p_order->>'created_at','')::timestamptz;
  exception when others then
    created_ts := now();
  end;
  created_ts := coalesce(created_ts, now());

  select reset_at, reset_order_id
    into cutoff_ts, cutoff_oid
  from public.system_reset_state
  where key = 'sales_orders';

  if cutoff_ts is not null and (created_ts < cutoff_ts or oid < coalesce(cutoff_oid, 0)) then
    return null;
  end if;

  mapped_status := case coalesce(p_order->>'status','pending')
    when 'pending' then 'new'
    when 'accepted' then 'accepted'
    when 'paid' then 'paid'
    when 'shipped' then 'shipping'
    when 'delivered' then 'shipping'
    when 'done' then 'shipping'
    when 'cancelled' then 'cancelled'
    else 'new'
  end;

  items_in := coalesce(p_order->'items','[]'::jsonb);
  if jsonb_typeof(items_in) <> 'array' then items_in := '[]'::jsonb; end if;

  for item in select * from jsonb_array_elements(items_in)
  loop
    begin tid := nullif(item->>'book_id','')::bigint; exception when others then tid := null; end;
    qty := greatest(1,coalesce((item->>'qty')::integer,(item->>'quantity')::integer,1));
    unit_price := greatest(0,coalesce((item->>'unit_price')::integer,(item->>'price')::integer,0));
    bid := null;
    if tid is not null then select id into bid from public.books where telegram_id=tid limit 1; end if;
    subtotal := subtotal + unit_price*qty;
    cnt := cnt + qty;
    safe_items := safe_items || jsonb_build_array(jsonb_build_object(
      'book_id', bid,
      'telegram_book_id', tid,
      'title', coalesce(nullif(item->>'name',''), nullif(item->>'title',''), 'Kitob'),
      'quantity', qty,
      'price', unit_price,
      'unit_price', unit_price,
      'line_total', unit_price*qty
    ));
  end loop;

  if cnt >= 4 then fee:=0; end if;

  select id,source,status into existing,existing_source,existing_status from public.orders where telegram_order_id=oid for update;
  -- A cancelled duplicate must never return to financial statistics from
  -- a delayed bot sync/retry carrying an older accepted status.
  if existing is not null and existing_status='cancelled' then
    return existing;
  end if;
  if existing is null then
    insert into public.orders(
      customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,status,items,
      stock_reserved,stock_restored,created_at,telegram_order_id,telegram_chat_id,telegram_username,
      telegram_receipt_file_id,source
    ) values (
      coalesce(nullif(trim(p_order->>'name'),''),'Telegram mijoz'),
      coalesce(nullif(trim(p_order->>'phone'),''),'0000000'),
      coalesce(nullif(trim(p_order->>'address'),''),'Telegram buyurtma'),
      '택배',fee,subtotal,subtotal+fee,mapped_status,safe_items,
      mapped_status in ('accepted','paid','shipping'),false,created_ts,oid,
      nullif(p_order->>'chat_id','')::bigint,coalesce(p_order->>'username',''),coalesce(p_order->>'receipt_file_id',''),'telegram'
    ) returning id into existing;
  else
    update public.orders set
      customer_name=coalesce(nullif(trim(p_order->>'name'),''),customer_name),
      phone=coalesce(nullif(trim(p_order->>'phone'),''),phone),
      address=coalesce(nullif(trim(p_order->>'address'),''),address),
      delivery_type='택배',delivery_fee=fee,subtotal=subtotal,total=subtotal+fee,
      status=mapped_status,items=safe_items,
      stock_reserved=mapped_status in ('accepted','paid','shipping'),
      telegram_chat_id=coalesce(nullif(p_order->>'chat_id','')::bigint,telegram_chat_id),
      telegram_username=coalesce(p_order->>'username',telegram_username),
      telegram_receipt_file_id=coalesce(p_order->>'receipt_file_id',telegram_receipt_file_id),
      source=case
        when existing_source='app' then 'app'
        when existing_source='instagram' then 'instagram'
        else 'telegram'
      end
    where id=existing;
  end if;
  return existing;
end;
$function$
;
