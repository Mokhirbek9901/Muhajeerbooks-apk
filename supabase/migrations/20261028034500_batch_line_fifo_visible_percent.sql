-- Include FIFO-based *estimated* outflow on the existing protected
-- batch line response so the history card always has enough data to show
-- units and percentage, without depending on a second optional report.
-- These fields are read-only: NEVER mutate books.stock, orders, sales or costs.
CREATE OR REPLACE FUNCTION public.admin_web_batch_line_list(p_secret text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $func$
BEGIN
 IF NOT coalesce(public.admin_verify(p_secret),false) THEN
   RAISE EXCEPTION 'Admin tasdiqlanmadi';
 END IF;
 RETURN coalesce((
  WITH ranked AS (
   SELECT l.*, b.title, b.stock,
     coalesce(nullif(b.thumbnail_url,''),b.image_url) cover_url,
     coalesce(sum(l.quantity::bigint) OVER (
       PARTITION BY l.book_id
       ORDER BY l.purchased_at DESC,l.id DESC
       ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
     ),0)::bigint AS newer_lot_units
   FROM public.web_book_batches l
   JOIN public.books b ON b.id=l.book_id
  ), projections AS (
   SELECT r.*,
     greatest(least(
       greatest(coalesce(r.stock,0),0)::bigint-r.newer_lot_units,
       r.quantity::bigint),0)::integer AS fifo_remaining_units
   FROM ranked r
  )
  SELECT jsonb_agg(jsonb_build_object(
    'id',l.id,'book_id',l.book_id,'title',l.title,
    'quantity',l.quantity,'unit_cost',l.unit_cost,
    'image_url',l.cover_url,
    'suggested_price',l.suggested_price,'purchased_at',l.purchased_at,
    'note',l.note,'cost_origin',l.cost_origin,
    'inventory_applied',l.inventory_applied,
    'batch_import_id',l.batch_import_id,
    'batch_group_id',l.batch_group_id,
    'batch_name',coalesce(g.title,i.title,'Alohida partiya'),
    'batch_type',CASE WHEN l.batch_import_id IS NOT NULL THEN 'finance'
      WHEN l.batch_group_id IS NOT NULL THEN 'catalog' ELSE 'legacy' END,
    'fifo_remaining_units',l.fifo_remaining_units,
    'fifo_outflow_units',l.quantity-l.fifo_remaining_units,
    'fifo_estimate_only',true
    ) ORDER BY l.purchased_at DESC,l.id DESC)
  FROM projections l
  LEFT JOIN public.web_batch_imports i ON i.id=l.batch_import_id
  LEFT JOIN public.web_batch_groups g ON g.id=l.batch_group_id
 ),'[]'::jsonb);
END $func$;
