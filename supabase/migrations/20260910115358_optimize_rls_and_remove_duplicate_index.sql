drop index if exists public.orders_telegram_order_id_uidx;

drop policy if exists profiles_self_select on public.profiles;
drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile"
on public.profiles
for select
to authenticated
using ((id = (select auth.uid())) or (select public.is_admin()));

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists orders_admin_select on public.orders;
drop policy if exists "customers can read own orders" on public.orders;
create policy "customers can read own orders"
on public.orders
for select
to authenticated
using ((customer_user_id = (select auth.uid())) or (select public.is_admin()));

drop policy if exists orders_insert_returning_post on public.orders;
create policy orders_insert_returning_post
on public.orders
for select
to anon
using (((select coalesce(current_setting('request.method', true), '')) = 'POST') and source = 'app');

revoke execute on function public._orders_sales_log_trigger() from public, anon, authenticated;
revoke execute on function public.attach_order_customer() from public, anon, authenticated;
revoke execute on function public.link_order_telegram_customer() from public, anon, authenticated;
revoke execute on function public.prepare_order_for_review() from public, anon, authenticated;
