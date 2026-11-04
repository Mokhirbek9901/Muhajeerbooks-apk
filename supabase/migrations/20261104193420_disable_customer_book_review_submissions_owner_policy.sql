-- User-requested permanent removal of customer-written book reviews.
-- Preserve historical reviews and all unrelated RPCs; disable ONLY posting.
-- Existing app versions calling the customer-rpc proxy cannot write reviews.
REVOKE EXECUTE ON FUNCTION public.customer_book_review_submit(
  uuid, text, uuid, integer, text
) FROM PUBLIC, anon, authenticated, service_role;
