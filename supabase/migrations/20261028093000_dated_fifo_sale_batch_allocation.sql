-- Read-only, date-based FIFO allocation for every recognized sold unit.
-- No write to orders, sales_log, inventory, finance, or profit snapshots.
CREATE OR REPLACE FUNCTION public.admin_web_batch_date_fifo(p_secret text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fifo$
DECLARE
  v_first_date date;
  v_sale record;
  v_lot record;
  v_used jsonb := '{}'::jsonb;
  v_known jsonb := '{}'::jsonb;
  v_legacy jsonb := '{}'::jsonb;
  v_revenue jsonb := '{}'::jsonb;
  v_cost jsonb := '{}'::jsonb;
  v_events jsonb := '[]'::jsonb;
  v_lots jsonb;
  v_assigned integer := 0;
  v_unmatched integer := 0;
  v_unknown_book integer := 0;
  v_legacy_matched integer := 0;
  v_current integer;
BEGIN
  IF NOT COALESCE(public.admin_verify(p_secret), false) THEN
    RAISE EXCEPTION 'Admin tasdiqlanmadi';
  END IF;

  SELECT min(purchased_at) INTO v_first_date
    FROM public.web_book_batches WHERE quantity > 0;
  IF v_first_date IS NULL THEN
    RETURN jsonb_build_object(
      'lots','[]'::jsonb,'assignments','[]'::jsonb,
      'matched_sold_units',0,'unmatched_sold_units',0,
      'unknown_book_units',0,'legacy_matched_units',0,
      'allocation_method','dated_fifo_sales',
      'generated_at', now());
  END IF;

  -- Only unambiguous title matches are acceptable for old/no-ID sales.
  -- Sales_log and pre-app legacy history do not overlap chronologically.
  -- Incoming lots become eligible on their receipt date (Korea time).
  FOR v_sale IN
    WITH unique_title AS (
      SELECT public.normalize_book_title(b.title) AS norm_title,
             min(b.id::text)::uuid AS book_id
      FROM public.books b
      GROUP BY public.normalize_book_title(b.title)
      HAVING count(*) = 1
    ), sales AS (
      SELECT 'order'::text AS origin, s.id AS source_id,
             coalesce(s.book_id,t.book_id) AS book_id,
             s.sold_at AS sold_at,
             s.unit_price AS unit_price, s.order_id,
             s.title
      FROM public.sales_log s
      LEFT JOIN unique_title t
        ON s.book_id IS NULL AND t.norm_title=public.normalize_book_title(s.title)
      WHERE (s.sold_at AT TIME ZONE 'Asia/Seoul')::date >= v_first_date
      UNION ALL
      SELECT 'legacy'::text, h.id, t.book_id, h.sold_at,
             NULL::integer, NULL::uuid, h.title
      FROM public.legacy_sales_history h
      LEFT JOIN unique_title t
        ON t.norm_title=public.normalize_book_title(h.title)
      WHERE (h.sold_at AT TIME ZONE 'Asia/Seoul')::date >= v_first_date
    )
    SELECT * FROM sales ORDER BY sold_at,origin,source_id
  LOOP
    IF v_sale.book_id IS NULL THEN
      v_unknown_book := v_unknown_book + 1;
      v_unmatched := v_unmatched + 1;
      CONTINUE;
    END IF;
    SELECT l.id,l.quantity,l.unit_cost,l.purchased_at
      INTO v_lot
      FROM public.web_book_batches l
      WHERE l.book_id=v_sale.book_id
        AND l.quantity > 0
        AND l.purchased_at <= (v_sale.sold_at AT TIME ZONE 'Asia/Seoul')::date
        AND l.quantity > coalesce((v_used->>(l.id::text))::integer,0)
      ORDER BY l.purchased_at ASC,l.id ASC
      LIMIT 1;

    IF NOT FOUND THEN
      v_unmatched := v_unmatched + 1;
      CONTINUE;
    END IF;

    v_current:=coalesce((v_used->>(v_lot.id::text))::integer,0);
    v_used:=jsonb_set(v_used,ARRAY[v_lot.id::text],to_jsonb(v_current+1),true);
    v_assigned:=v_assigned+1;

    IF v_sale.origin='order' THEN
      v_current:=coalesce((v_known->>(v_lot.id::text))::integer,0);
      v_known:=jsonb_set(v_known,ARRAY[v_lot.id::text],to_jsonb(v_current+1),true);
      v_current:=coalesce((v_revenue->>(v_lot.id::text))::bigint,0);
      v_revenue:=jsonb_set(v_revenue,ARRAY[v_lot.id::text],
        to_jsonb(v_current+coalesce(v_sale.unit_price,0)),true);
      v_current:=coalesce((v_cost->>(v_lot.id::text))::bigint,0);
      v_cost:=jsonb_set(v_cost,ARRAY[v_lot.id::text],
        to_jsonb(v_current+v_lot.unit_cost),true);
    ELSE
      v_current:=coalesce((v_legacy->>(v_lot.id::text))::integer,0);
      v_legacy:=jsonb_set(v_legacy,ARRAY[v_lot.id::text],to_jsonb(v_current+1),true);
      v_legacy_matched:=v_legacy_matched+1;
    END IF;

    v_events:=v_events || jsonb_build_array(jsonb_build_object(
      'lot_id',v_lot.id,
      'book_id',v_sale.book_id,
      'source',v_sale.origin,
      'source_id',v_sale.source_id,
      'order_id',v_sale.order_id,
      'sold_at',v_sale.sold_at,
      'sale_date',(v_sale.sold_at AT TIME ZONE 'Asia/Seoul')::date,
      'receipt_date',v_lot.purchased_at,
      'sale_price',v_sale.unit_price,
      'lot_unit_cost',v_lot.unit_cost));
  END LOOP;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',l.id,
    'book_id',l.book_id,
    'purchased_at',l.purchased_at,
    'quantity',l.quantity,
    'fifo_outflow_units',coalesce((v_used->>(l.id::text))::integer,0),
    'fifo_remaining_units',greatest(l.quantity-coalesce((v_used->>(l.id::text))::integer,0),0),
    'dated_order_sales_units',coalesce((v_known->>(l.id::text))::integer,0),
    'dated_legacy_sales_units',coalesce((v_legacy->>(l.id::text))::integer,0),
    'dated_order_revenue',coalesce((v_revenue->>(l.id::text))::bigint,0),
    'dated_lot_cost',coalesce((v_cost->>(l.id::text))::bigint,0),
    'dated_order_gross_profit',coalesce((v_revenue->>(l.id::text))::bigint,0)
        -coalesce((v_cost->>(l.id::text))::bigint,0)
    ) ORDER BY l.purchased_at,l.id),'[]'::jsonb)
  INTO v_lots
  FROM public.web_book_batches l WHERE l.quantity>0;

  RETURN jsonb_build_object(
    'lots',v_lots,'assignments',v_events,
    'matched_sold_units',v_assigned,
    'unmatched_sold_units',v_unmatched,
    'unknown_book_units',v_unknown_book,
    'legacy_matched_units',v_legacy_matched,
    'allocation_method','dated_fifo_sales',
    'allocation_note','Sotuv Koreya sanasi bo‘yicha eng eski, hali tugamagan va sotuv sanasidan kech bo‘lmagan partiyaga bog‘lanadi. Eski partiyada qoldiq bo‘lsa, yangi partiya kelganda ham avval eski qoldiq sarflanadi. Nomi ishonchli topilmagan yoki yetarli tarixiy partiyasi bo‘lmagan sotuvlar biriktirilmaydi. Hisob sanalar asosidagi qayta hisoblanadigan bog‘lash; sotuv va ombor yozuvlari o‘zgarmaydi.',
    'generated_at',now());
END;
$fifo$;

REVOKE ALL ON FUNCTION public.admin_web_batch_date_fifo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_web_batch_date_fifo(text)
  TO anon,authenticated,service_role;
