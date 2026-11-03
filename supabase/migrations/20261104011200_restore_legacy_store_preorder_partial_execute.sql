-- Compatibility patch for existing Muhajeer Books Android/iOS versions.
-- Those store binaries may call this exact RPC directly via PostgREST.
-- 42501 permission denied stopped customers at "qolgan to'lov".
--
-- Function-level authorization is mandatory and preserved:
--   device:* -> private.customer_device validates secret hash and
--               private.customer_device_owns_preorder checks order/device.
--   legacy PIN -> private.release_assert_owner checks session/order/phone.
-- Actions are restricted to detail/choose/proof; proof checks device-bound
-- receipt ownership and duplicate-use safeguards.
-- Do not grant admin functions, tables, private helpers, or other RPCs.
GRANT EXECUTE
  ON FUNCTION public.customer_web_preorder_partial(text, uuid, text, jsonb)
  TO anon, authenticated;
