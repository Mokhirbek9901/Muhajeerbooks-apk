-- Read-only date-paged admin heatmap, 2024-April onward.
-- Existing 30-day report remains unchanged; financial snapshots are never rewritten.
CREATE OR REPLACE FUNCTION public.admin_book_sales_activity_range(
 p_secret text, p_from date, p_to date
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_today date := (now() at time zone 'Asia/Seoul')::date;
 v_result jsonb;
BEGIN
 IF NOT coalesce(public.admin_verify(p_secret),false) THEN
   RAISE EXCEPTION 'Admin tasdiqlanmadi';
 END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_from < date '2024-04-01'
    OR p_to > v_today OR p_to < p_from OR p_to-p_from > 1500 THEN
   RAISE EXCEPTION 'Sana oralig‘i noto‘g‘ri';
 END IF;
 WITH calendar AS (
   SELECT d::date sale_day FROM generate_series(p_from,p_to,interval '1 day') d
 ), actual_sales AS (
   SELECT (coalesce(ps.first_sold_at,s.sold_at) at time zone 'Asia/Seoul')::date sale_day,
          1::integer sold,0::integer historic_sold,
          coalesce(ps.unit_price,s.unit_price)::bigint revenue,
          CASE WHEN coalesce(ps.cost_known,s.unit_cost>0)
            THEN (coalesce(ps.unit_price,s.unit_price)-coalesce(ps.unit_cost,s.unit_cost))::bigint
            ELSE NULL::bigint END profit
   FROM public.sales_log s
   LEFT JOIN private.book_sale_profit_snapshots ps
     ON ps.order_id=s.order_id AND ps.item_index=s.item_index
        AND ps.unit_index=s.unit_index
   WHERE coalesce(ps.first_sold_at,s.sold_at) >=
         (p_from::timestamp at time zone 'Asia/Seoul')
     AND coalesce(ps.first_sold_at,s.sold_at) <
         ((p_to+1)::timestamp at time zone 'Asia/Seoul')
   UNION ALL
   SELECT (coalesce(h.sold_at,h.created_at) at time zone 'Asia/Seoul')::date,
          1::integer,1::integer,NULL::bigint,NULL::bigint
   FROM public.legacy_sales_history h
   WHERE coalesce(h.sold_at,h.created_at) >=
         (p_from::timestamp at time zone 'Asia/Seoul')
     AND coalesce(h.sold_at,h.created_at) <
         ((p_to+1)::timestamp at time zone 'Asia/Seoul')
 ), daily AS (
   SELECT sale_day,sum(sold)::integer sold,
       sum(historic_sold)::integer historic_sold,
       count(revenue)::integer priced_units,
       count(profit)::integer known_cost_units,
       sum(revenue)::bigint revenue,
       sum(profit)::bigint profit
   FROM actual_sales GROUP BY sale_day
 )
 SELECT jsonb_build_object(
   'from',p_from,'to',p_to,
   'earliest_date',date '2024-04-01',
   'days',coalesce(jsonb_agg(jsonb_build_object(
      'date',c.sale_day,'sold',coalesce(d.sold,0),
      'historic_sold',coalesce(d.historic_sold,0),
      'priced_units',coalesce(d.priced_units,0),
      'known_cost_units',coalesce(d.known_cost_units,0),
      'revenue',d.revenue,'profit',d.profit
   ) order by c.sale_day),'[]'::jsonb),
   'total_sold',coalesce(sum(d.sold),0),
   'active_days',count(*) filter(where coalesce(d.sold,0)>0),
   'historic_sold',coalesce(sum(d.historic_sold),0),
   'generated_at',now()
 ) INTO v_result FROM calendar c LEFT JOIN daily d USING(sale_day);
 RETURN v_result;
END;
$fn$;
REVOKE ALL ON FUNCTION public.admin_book_sales_activity_range(text,date,date)
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_book_sales_activity_range(text,date,date)
  TO service_role,anon,authenticated;

