-- Applied to production on 2026-09-06.
-- Professional order flow:
-- 1) orders are validated on insert but stock is NOT reduced;
-- 2) admin status 'accepted' atomically reserves/decrements stock;
-- 3) cancellation restores stock only when it had been reserved;
-- 4) payment_proof_path/payment_submitted_at store private receipt references;
-- 5) payment-receipts is a private Storage bucket;
-- 6) customer_order_statuses(uuid[]) exposes only status metadata for locally saved customer receipts.

-- The live database migration was applied through Supabase before this source release.
