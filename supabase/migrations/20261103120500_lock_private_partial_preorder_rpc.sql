-- Extra defense in depth: partial batch mutators only run as service_role
-- through authenticated admin_release_preorder/customer_release_preorder
-- routes, which verify the admin secret or device/PIN order ownership.
-- Existing customer orders, payments, stock, covers, and notification rows
-- are not modified. Never grant either helper to public, anon, authenticated.
revoke all on function public.admin_web_preorder_partial(text,uuid,text,jsonb)
  from public, anon, authenticated;
revoke all on function public.customer_web_preorder_partial(text,uuid,text,jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_web_preorder_partial(text,uuid,text,jsonb)
  to service_role;
grant execute on function public.customer_web_preorder_partial(text,uuid,text,jsonb)
  to service_role;
