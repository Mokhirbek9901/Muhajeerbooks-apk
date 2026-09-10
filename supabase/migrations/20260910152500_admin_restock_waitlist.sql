create or replace function public.admin_restock_waitlist(p_secret text)
returns table(
  book_id uuid,
  title text,
  image_url text,
  stock integer,
  waiting_count bigint,
  first_requested_at timestamptz,
  last_requested_at timestamptz
)
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;

  return query
  select
    b.id,
    b.title,
    coalesce(b.image_url, ''),
    b.stock,
    count(*)::bigint as waiting_count,
    min(rs.created_at) as first_requested_at,
    max(rs.created_at) as last_requested_at
  from public.restock_subscriptions rs
  join public.books b on b.id = rs.book_id
  where rs.notified_at is null
    and b.is_active = true
    and (b.stock <= 0 or b.price <= 0)
  group by b.id, b.title, b.image_url, b.stock
  order by count(*) desc, max(rs.created_at) desc, b.title;
end;
$$;

revoke all on function public.admin_restock_waitlist(text) from public;
grant execute on function public.admin_restock_waitlist(text) to anon, authenticated;
