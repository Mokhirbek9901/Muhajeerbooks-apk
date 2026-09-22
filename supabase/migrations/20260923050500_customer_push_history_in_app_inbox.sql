create or replace function public.customer_push_history(p_limit integer default 50)
returns table(
  id uuid,
  title text,
  body text,
  sent_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select m.id, m.title, m.body, m.sent_at
  from public.push_messages m
  where m.sent_at is not null
  order by m.sent_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.customer_push_history(integer) from public;
grant execute on function public.customer_push_history(integer) to service_role;
