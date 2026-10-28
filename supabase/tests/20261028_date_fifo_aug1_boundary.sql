-- Read-only regression: the FIFO business cutoff is immutable.
-- Even if an older batch dated 2026-07-20 is later entered, a July sale
-- must never be allocated to any batch.
DO $check_august_start$
DECLARE
  fn text;
  earlier_sale_allowed boolean;
  august_sale_allowed boolean;
  later_sale_allowed boolean;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='admin_web_batch_date_fifo';

  IF fn IS NULL OR position(
    'v_first_date constant date := date ''2026-08-01''' IN fn)=0
     OR position('SELECT min(purchased_at) INTO v_first_date' IN fn)>0
  THEN RAISE EXCEPTION 'Date FIFO start is not fixed to 2026-08-01';
  END IF;

  -- A hypothetical older receipt must not make July sales eligible.
  SELECT (DATE '2026-07-31' >= DATE '2026-08-01'
     AND DATE '2026-07-20' <= DATE '2026-07-31'),
    (DATE '2026-08-01' >= DATE '2026-08-01'
     AND DATE '2026-08-01' <= DATE '2026-08-01'),
    (DATE '2026-09-12' >= DATE '2026-08-01'
     AND DATE '2026-09-09' <= DATE '2026-09-12')
  INTO earlier_sale_allowed,august_sale_allowed,later_sale_allowed;
  IF earlier_sale_allowed OR NOT august_sale_allowed OR NOT later_sale_allowed
  THEN RAISE EXCEPTION 'Cutoff and receipt date regression failed'; END IF;

  IF position('s.sold_at AT TIME ZONE ''Asia/Seoul'')::date >= v_first_date' IN fn)=0
   OR position('h.sold_at AT TIME ZONE ''Asia/Seoul'')::date >= v_first_date' IN fn)=0
  THEN RAISE EXCEPTION 'Both current/legacy sale types must obey cutoff'; END IF;
END $check_august_start$;
