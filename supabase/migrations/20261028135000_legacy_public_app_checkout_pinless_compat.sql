-- Existing public App Store/Play Store builds do not yet expose the new
-- customer PIN profile flow. Keep their legacy customer_order_submit API
-- usable while the new customer_release_order API remains PIN protected.
-- Compatibility never trusts client prices, shipping, admin flags, or stock.
DO $verify_legacy_function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='customer_order_submit'
      AND position('Buyurtma uchun ilovani yangilang va PIN bilan kiring'
       in pg_get_functiondef(p.oid))>0
  ) THEN
    RAISE EXCEPTION 'Legacy checkout has changed; refusing blind overwrite';
  END IF;
END $verify_legacy_function$;

CREATE OR REPLACE FUNCTION public.customer_order_submit(p_order jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $legacy_checkout$
DECLARE
  v_id uuid;
  v_name text;
  v_phone text;
  v_address text;
  v_delivery_type text;
  v_proof text;
  v_old public.orders%rowtype;
  v_session text;
BEGIN
  IF p_order IS NULL OR jsonb_typeof(p_order)<>'object' THEN
    RAISE EXCEPTION 'Buyurtma ma’lumoti noto‘g‘ri';
  END IF;

  -- New signed-in clients must use the PIN-protected quote/order API.
  -- PIN-less old app builds use this narrow legacy path until published
  -- app updates actually reach their users.
  v_session := trim(coalesce(p_order->>'session',''));
  IF v_session<>'' THEN
    IF private.pin_session_phone(v_session) IS NULL THEN
      RAISE EXCEPTION 'PIN sessiyasi noto‘g‘ri';
    END IF;
    IF public._customer_phone_key(coalesce(p_order->>'phone','')) IS DISTINCT FROM
       private.pin_session_phone(v_session) THEN
      RAISE EXCEPTION 'Profil telefonini ishlating';
    END IF;
  END IF;

  IF coalesce((p_order->>'entered_by_admin')::boolean,false)
     OR p_order ? 'manual_subtotal'
  THEN
    RAISE EXCEPTION 'Professional buyurtmalar faqat admin sessiyasi orqali';
  END IF;

  v_name := trim(coalesce(p_order->>'customer_name',''));
  v_phone := trim(coalesce(p_order->>'phone',''));
  v_address := trim(coalesce(p_order->>'address',''));
  v_delivery_type := trim(coalesce(p_order->>'delivery_type','택배'));
  v_proof := trim(coalesce(p_order->>'payment_proof_path',''));
  v_id := coalesce(nullif(trim(coalesce(p_order->>'id','')),'')::uuid,
    gen_random_uuid());

  IF length(v_name) NOT BETWEEN 2 AND 100 OR
     length(regexp_replace(v_phone,'[^0-9]','','g')) NOT BETWEEN 7 AND 16 OR
     length(v_phone)>32 THEN
    RAISE EXCEPTION 'Ism yoki telefon noto‘g‘ri';
  END IF;
  IF lower(v_delivery_type)='gyeongsan' THEN
    v_delivery_type:='경산 직접수령';
  END IF;
  IF v_delivery_type NOT IN ('택배','경산 직접수령') THEN
    RAISE EXCEPTION 'Yetkazish turi noto‘g‘ri';
  END IF;
  IF v_delivery_type='택배' AND length(v_address)<8 THEN
    RAISE EXCEPTION 'To‘liq manzilni kiriting';
  END IF;
  IF length(v_address)>500 THEN
    RAISE EXCEPTION 'Manzil juda uzun';
  END IF;
  IF jsonb_typeof(p_order->'items')<>'array' OR
     jsonb_array_length(p_order->'items') NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'Buyurtma savatchasi bo‘sh yoki noto‘g‘ri';
  END IF;
  IF p_order ? 'bundle_selections' AND
     jsonb_typeof(p_order->'bundle_selections')<>'array' THEN
    RAISE EXCEPTION 'Kitob setlari noto‘g‘ri';
  END IF;

  -- Existing receipt upload works without PIN on the public old app.
  -- Storage object and filename are checked again by the insert trigger.
  IF v_proof !~ '^receipts/[A-Za-z0-9._/-]+$' OR
     length(v_proof)>400 OR
     NOT EXISTS (
       SELECT 1 FROM storage.objects obj
       WHERE obj.bucket_id='payment-receipts' AND obj.name=v_proof
     ) THEN
    RAISE EXCEPTION 'Haqiqiy to‘lov chekini tanlang';
  END IF;

  -- Stable order IDs and receipt paths prevent duplicate stock reservations
  -- if a legacy client retries a slow request.
  PERFORM pg_advisory_xact_lock(hashtextextended(
    'legacy-checkout:'||v_id::text,20261028));
  SELECT * INTO v_old FROM public.orders WHERE id=v_id;
  IF FOUND THEN
    IF v_old.source='app' AND NOT v_old.entered_by_admin AND
       v_old.payment_proof_path=v_proof AND v_old.phone=v_phone AND
       v_old.customer_name=v_name THEN
      RETURN v_id;
    END IF;
    RAISE EXCEPTION 'Buyurtma IDsi boshqa buyurtmaga tegishli';
  END IF;

  -- Never allow a customer to use someone else's previously applied receipt.
  IF EXISTS (SELECT 1 FROM public.orders WHERE payment_proof_path=v_proof)
     OR EXISTS (SELECT 1 FROM public.preorders WHERE payment_proof_path=v_proof)
     OR EXISTS (
       SELECT 1 FROM public.web_preorder_requests
       WHERE payment_proof_path=v_proof
     )
  THEN
    RAISE EXCEPTION 'Bu chek boshqa buyurtmada ishlatilgan';
  END IF;

  -- The before-insert triggers recompute EVERY book price, bundle, shipping
  -- and total from trusted database values, validate the receipt and reserve
  -- physical inventory atomically. Client amount/discount/status ignored.
  INSERT INTO public.orders (
    id,customer_name,phone,address,delivery_type,delivery_fee,
    subtotal,total,status,source,items,bundle_selections,
    payment_proof_path,payment_submitted_at,
    instagram_handle,order_note,entered_by_admin,payment_status
  ) VALUES (
    v_id,v_name,v_phone,v_address,v_delivery_type,0,
    0,0,'new','app',p_order->'items',
    coalesce(p_order->'bundle_selections','[]'::jsonb),
    v_proof,now(),
    left(coalesce(p_order->>'instagram_handle',''),120),
    left(coalesce(p_order->>'order_note',''),1000),
    false,'paid'
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id=v_id AND o.source='app'
      AND o.payment_proof_path=v_proof
      AND o.stock_reserved=true
  ) THEN
    RAISE EXCEPTION 'Buyurtma saqlanmadi';
  END IF;
  RETURN v_id;
END
$legacy_checkout$;

-- Continue to expose legacy submission ONLY to the existing server-side
-- service role (customer-rpc edge validates/rate-limits client requests).
REVOKE ALL ON FUNCTION public.customer_order_submit(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.customer_order_submit(jsonb) TO service_role;
