drop policy if exists orders_insert_returning_post on public.orders;

create policy orders_insert_returning_post
on public.orders
for select
to anon
using (
  coalesce((select current_setting('request.method', true)), '') = 'POST'
  and source = 'app'
);
