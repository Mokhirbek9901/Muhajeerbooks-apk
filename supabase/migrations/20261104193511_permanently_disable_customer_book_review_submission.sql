-- Owner explicitly removed all customer review writing.
-- Keep existing book_reviews rows untouched for audit/history.
-- This blocks old iOS/Android binaries as well as newly updated clients,
-- without affecting order status, shipping, catalog, or preorder RPCs.
CREATE OR REPLACE FUNCTION public.customer_book_review_submit(
  p_order_id uuid, p_phone text, p_book_id uuid, p_rating integer, p_comment text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'Kitoblar uchun sharh yozish o‘chirilgan.';
END;
$function$;

