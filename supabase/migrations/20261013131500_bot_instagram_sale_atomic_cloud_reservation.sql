-- A saved Instagram sale must reserve stock in the same transaction as
-- its newly created cloud order, BEFORE optional shipping details are entered.
-- Backfills/replays continue using preserve_stock without instant_stock_reserve.
-- Existing bot_mark_instagram_order validates and locks stock; any shortfall
-- aborts the entire order creation rather than leaving a phantom sale.
CREATE OR REPLACE FUNCTION public.bot_order_create(p_secret text, p_order jsonb, p_preserve_stock boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tid bigint; v_chat bigint; v_id uuid; v_existing public.orders%rowtype; v_status text;
  item jsonb; kv record; bk public.books%rowtype; qty integer; unit_price integer;
  safe_items jsonb := '[]'::jsonb; v_subtotal integer := 0; v_count integer := 0;
  v_fee integer := 4000; v_is_instagram boolean := false; v_created_at timestamptz;
  cutoff_ts timestamptz; cutoff_oid bigint; v_stocks jsonb;
begin
  if not public._secret_ok(p_secret, 'ff2c7a6de8f32fb3153d1f01a7e9b171005789f249f364bd5bc6bf2210c6adfd') then raise exception 'Ruxsat yo‘q'; end if;
  begin v_tid := nullif(p_order->>'order_id','')::bigint; exception when others then v_tid := null; end;
  if v_tid is null or v_tid <= 0 then raise exception 'Buyurtma raqami noto‘g‘ri'; end if;
  begin v_created_at := nullif(p_order->>'created_at','')::timestamptz; exception when others then v_created_at := now(); end;
  v_created_at := coalesce(v_created_at,now());
  select reset_at,reset_order_id into cutoff_ts,cutoff_oid from public.system_reset_state where key='sales_orders';
  if cutoff_ts is not null and (v_created_at < cutoff_ts or v_tid < coalesce(cutoff_oid,0)) then raise exception 'Resetdan oldingi sinov buyurtmasi qabul qilinmaydi'; end if;
  select * into v_existing from public.orders ord where ord.telegram_order_id=v_tid;
  if found then
    select coalesce(jsonb_object_agg(coalesce(bk2.telegram_id::text,bk2.id::text),bk2.stock),'{}'::jsonb) into v_stocks
    from public.books bk2 where bk2.id in (select (x->>'book_id')::uuid from jsonb_array_elements(v_existing.items) x);
    return jsonb_build_object('id',v_existing.id,'order_number',v_existing.display_order_number,'status',v_existing.status,'stocks',v_stocks);
  end if;
  begin v_chat := nullif(p_order->>'chat_id','')::bigint; exception when others then v_chat:=null; end;
  v_is_instagram := lower(coalesce(p_order->>'source',''))='instagram';
  if jsonb_typeof(p_order->'items')='array' and jsonb_array_length(p_order->'items')>0 then
    for item in select * from jsonb_array_elements(p_order->'items') loop
      begin select * into bk from public.books bq where bq.telegram_id=(item->>'book_id')::bigint and bq.is_active=true;
      exception when others then raise exception 'Buyurtmadagi kitob IDsi noto‘g‘ri'; end;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi: %',item->>'book_id'; end if;
      begin qty:=greatest(1,coalesce(nullif(item->>'qty','')::integer,nullif(item->>'quantity','')::integer,1)); exception when others then raise exception 'Kitob soni noto‘g‘ri'; end;
      if qty>100 then raise exception 'Bitta kitobdan juda ko‘p miqdor kiritildi'; end if;
      if v_is_instagram then begin unit_price:=greatest(0,coalesce(nullif(item->>'unit_price','')::integer,nullif(item->>'price','')::integer,round(bk.price*(100-(case when bk.discount_percent>0 and (bk.discount_ends_at is null or bk.discount_ends_at>clock_timestamp()) then greatest(0,least(99,bk.discount_percent)) else 0 end))/100.0)::integer)); exception when others then unit_price:=round(bk.price*(100-(case when bk.discount_percent>0 and (bk.discount_ends_at is null or bk.discount_ends_at>clock_timestamp()) then greatest(0,least(99,bk.discount_percent)) else 0 end))/100.0)::integer; end; else unit_price:=round(bk.price*(100-(case when bk.discount_percent>0 and (bk.discount_ends_at is null or bk.discount_ends_at>clock_timestamp()) then greatest(0,least(99,bk.discount_percent)) else 0 end))/100.0)::integer; end if;
      v_subtotal:=v_subtotal+unit_price*qty; v_count:=v_count+qty;
      safe_items:=safe_items||jsonb_build_array(jsonb_build_object('book_id',bk.id,'telegram_book_id',bk.telegram_id,'title',bk.title,'quantity',qty,'price',unit_price,'unit_price',unit_price,'line_total',unit_price*qty));
    end loop;
  elsif jsonb_typeof(p_order->'cart')='object' then
    for kv in select * from jsonb_each_text(p_order->'cart') loop
      begin select * into bk from public.books bq where bq.telegram_id=kv.key::bigint and bq.is_active=true; exception when others then raise exception 'Buyurtmadagi kitob IDsi noto‘g‘ri'; end;
      if not found then raise exception 'Buyurtmadagi kitob topilmadi: %',kv.key; end if;
      begin qty:=greatest(1,kv.value::integer); exception when others then raise exception 'Kitob soni noto‘g‘ri'; end;
      if qty>100 then raise exception 'Bitta kitobdan juda ko‘p miqdor kiritildi'; end if;
      unit_price:=round(bk.price*(100-(case when bk.discount_percent>0 and (bk.discount_ends_at is null or bk.discount_ends_at>clock_timestamp()) then greatest(0,least(99,bk.discount_percent)) else 0 end))/100.0)::integer;
      v_subtotal:=v_subtotal+unit_price*qty; v_count:=v_count+qty;
      safe_items:=safe_items||jsonb_build_array(jsonb_build_object('book_id',bk.id,'telegram_book_id',bk.telegram_id,'title',bk.title,'quantity',qty,'price',unit_price,'unit_price',unit_price,'line_total',unit_price*qty));
    end loop;
  end if;
  if jsonb_array_length(safe_items)=0 then raise exception 'Buyurtma savatchasi bo‘sh'; end if;
  if v_is_instagram and p_preserve_stock then begin v_fee:=case when coalesce((p_order->>'delivery_fee')::integer,0)>=4000 then 4000 else 0 end; exception when others then v_fee:=0; end;
  else v_fee:=case when v_count>=4 then 0 else 4000 end; end if;
  insert into public.orders(customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,items,source,telegram_order_id,telegram_chat_id,telegram_username,telegram_receipt_file_id,payment_submitted_at,created_at)
  values(coalesce(nullif(trim(p_order->>'name'),''),'Telegram mijoz'),coalesce(nullif(trim(p_order->>'phone'),''),'00000000'),coalesce(nullif(trim(p_order->>'address'),''),'Manzil ko‘rsatilmagan'),'택배',v_fee,v_subtotal,v_subtotal+v_fee,safe_items,'telegram',v_tid,v_chat,coalesce(p_order->>'username',''),coalesce(p_order->>'receipt_file_id',''),now(),v_created_at)
  returning id into v_id;
  if p_preserve_stock and coalesce(p_order->>'status','pending') not in ('pending','new') then
    v_status:=case coalesce(p_order->>'status','pending') when 'accepted' then 'accepted' when 'paid' then 'paid' when 'shipped' then 'shipping' when 'delivered' then 'shipping' when 'done' then 'shipping' when 'cancelled' then 'cancelled' else 'new' end;
    update public.orders ord set status=v_status,stock_reserved=(v_status in ('accepted','paid','shipping')),stock_restored=false where ord.id=v_id;
  else perform public._order_set_status_core(v_id,'new'); end if;
  -- Current Instagram direct sales must reserve stock atomically together
  -- with the cloud order; historical replays that do not set this explicit
  -- marker retain the previous preserve-stock behaviour.
  if v_is_instagram and p_preserve_stock
     and coalesce(p_order->>'instant_stock_reserve','false') = 'true' then
    perform public.bot_mark_instagram_order(p_secret, v_id);
  end if;
  select * into v_existing from public.orders ord where ord.id=v_id;
  select coalesce(jsonb_object_agg(coalesce(bk2.telegram_id::text,bk2.id::text),bk2.stock),'{}'::jsonb) into v_stocks
  from public.books bk2 where bk2.id in (select (x->>'book_id')::uuid from jsonb_array_elements(v_existing.items) x);
  return jsonb_build_object('id',v_existing.id,'order_number',v_existing.display_order_number,'status',v_existing.status,'stocks',v_stocks);
end; $function$
;
