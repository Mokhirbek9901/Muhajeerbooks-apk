-- Permit the completed/mailed ('fulfilled') preorder state used by the
-- existing admin_release_preorder('shipped') action in the iOS TestFlight app.
-- This is schema-only. Do not touch past customer orders, payments or stock.
-- Keep every previously supported value, for web and native preorders.

alter table public.web_preorder_requests
  drop constraint web_preorder_requests_status_check,
  add constraint web_preorder_requests_status_check
    check (status in ('waiting','accepted','arrived','cancelled','fulfilled'));

alter table public.preorders
  drop constraint preorders_status_check,
  add constraint preorders_status_check
    check (status in ('waiting','contacted','converted','cancelled','accepted','arrived','fulfilled'));
