-- Regression checks: old public clients must reach normal server guards
-- without a PIN, but must NEVER bypass receipt, inventory or admin checks.
DO $legacy_checkout_regression$
DECLARE
  v_err text;
  v_test jsonb;
  v_before_orders bigint;
  v_before_stock bigint;
BEGIN
  SELECT count(*) INTO v_before_orders FROM public.orders;
  SELECT coalesce(sum(stock),0) INTO v_before_stock FROM public.books;
  v_test := jsonb_build_object(
    'customer_name','Public App Regression Test',
    'phone','01000000000',
    'address','Test street 123',
    'delivery_type','택배',
    'subtotal',1,
    'delivery_fee',0,
    'items',jsonb_build_array(jsonb_build_object(
      'book_id','11111111-1111-4111-8111-111111111111',
      'quantity',1,
      'price',1
    )),
    'payment_proof_path',''
  );

  BEGIN
    PERFORM public.customer_order_submit(v_test);
    RAISE EXCEPTION 'Expected receipt rejection';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE '%Haqiqiy to‘lov chekini tanlang%' THEN
      RAISE EXCEPTION 'Old client must reach receipt guard, got: %',v_err;
    END IF;
  END;
  BEGIN
    PERFORM public.customer_order_submit(v_test ||
      '{"entered_by_admin":true}'::jsonb);
    RAISE EXCEPTION 'Expected admin privilege rejection';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE '%Professional buyurtmalar faqat admin sessiyasi orqali%' THEN
      RAISE EXCEPTION 'Legacy admin bypass risk: %',v_err;
    END IF;
  END;
  BEGIN
    PERFORM public.customer_order_submit(v_test ||
      '{"manual_subtotal":1}'::jsonb);
    RAISE EXCEPTION 'Expected manual cost rejection';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE '%Professional buyurtmalar faqat admin sessiyasi orqali%' THEN
      RAISE EXCEPTION 'Legacy price override risk: %',v_err;
    END IF;
  END;
  BEGIN
    PERFORM public.customer_order_submit(v_test ||
      '{"session":"wrong-session"}'::jsonb);
    RAISE EXCEPTION 'Expected invalid PIN session rejection';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE '%PIN sessiyasi noto‘g‘ri%' THEN
      RAISE EXCEPTION 'Invalid session bypass: %',v_err;
    END IF;
  END;

  IF (SELECT count(*) FROM public.orders)<>v_before_orders
     OR (SELECT coalesce(sum(stock),0) FROM public.books)<>v_before_stock THEN
    RAISE EXCEPTION 'Rejected legacy checkout modified orders/stock';
  END IF;
  IF has_function_privilege('anon','public.customer_order_submit(jsonb)','EXECUTE')
     OR has_function_privilege('authenticated','public.customer_order_submit(jsonb)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.customer_order_submit(jsonb)','EXECUTE') THEN
    RAISE EXCEPTION 'Legacy RPC access control mismatch';
  END IF;
END $legacy_checkout_regression$;