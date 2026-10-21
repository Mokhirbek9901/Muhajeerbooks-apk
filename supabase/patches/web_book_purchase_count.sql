-- Additive, read-only public metric. No orders, stock, sales or RLS are changed.
-- Definer access is intentional: the response exposes counts only; raw sales,
-- order/customer details, prices and costs remain private.
create function public.web_book_purchase_count(p_book_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
set statement_timeout = '3s'
as $function$
  with target as (
    select b.id, b.telegram_id, public.normalize_book_title(b.title) as title_key
    from public.books b where b.id = p_book_id and b.is_active
  )
  select jsonb_build_object(
    'recorded_count', (
      select count(*) from public.sales_log s
      join public.orders o on o.id = s.order_id
      where (s.book_id = t.id or
        (s.book_id is null and s.telegram_book_id = t.telegram_id))
        and (o.status = 'shipping' or
          (coalesce(o.source, 'app') in ('app', 'telegram', 'instagram')
            and o.status in ('accepted', 'paid')))
    ),
    'historical_count', (
      select count(*) from public.legacy_sales_history h
      where public.normalize_book_title(h.title) = t.title_key
        -- Historic records have titles only. Never assign an ambiguous title
        -- to multiple editions/books or use fuzzy matching to inflate a count.
        and (select count(*) from public.books b
             where public.normalize_book_title(b.title) = t.title_key) = 1
    )
  ) from target t;
$function$;
revoke all on function public.web_book_purchase_count(uuid) from public;
grant execute on function public.web_book_purchase_count(uuid) to anon, authenticated, service_role;
comment on function public.web_book_purchase_count(uuid) is
  'Web-only storefront metric: sold copies from confirmed sales plus unambiguous legacy history; returns aggregate counts only.';
