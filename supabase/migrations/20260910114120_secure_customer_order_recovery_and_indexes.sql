create or replace function public.customer_restore_orders(
  p_phone text,
  p_recovery_code text
)
returns table(
  id uuid,
  customer_name text,
  phone text,
  address text,
  delivery_type text,
  delivery_fee integer,
  subtotal integer,
  total integer,
  status text,
  source text,
  items jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  payment_proof_path text,
  payment_submitted_at timestamptz,
  stock_reserved boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone_key text := public._customer_phone_key(p_phone);
  v_code text := lower(regexp_replace(trim(coalesce(p_recovery_code, '')), '[^0-9a-f]', '', 'g'));
begin
  if v_phone_key = '' then
    raise exception 'Telefon raqami noto‘g‘ri';
  end if;

  if length(v_code) < 12 then
    raise exception 'Tiklash kodi kamida 12 belgidan iborat bo‘lsin';
  end if;

  if not exists (
    select 1
      from public.orders o
     where o.source = 'app'
       and public._customer_phone_key(o.phone) = v_phone_key
       and right(replace(lower(o.id::text), '-', ''), 12) = right(v_code, 12)
  ) then
    raise exception 'Telefon yoki tiklash kodi mos kelmadi';
  end if;

  return query
  select
    o.id,
    o.customer_name,
    o.phone,
    o.address,
    o.delivery_type,
    o.delivery_fee,
    o.subtotal,
    o.total,
    o.status,
    o.source,
    o.items,
    o.created_at,
    o.updated_at,
    coalesce(o.payment_proof_path, ''),
    o.payment_submitted_at,
    o.stock_reserved
  from public.orders o
  where o.source = 'app'
    and public._customer_phone_key(o.phone) = v_phone_key
  order by o.created_at desc
  limit 50;
end;
$$;

revoke all on function public.customer_restore_orders(text, text) from public;
grant execute on function public.customer_restore_orders(text, text) to anon, authenticated;

create index if not exists app_installations_user_id_idx
  on public.app_installations(user_id)
  where user_id is not null;

create index if not exists restock_subscriptions_book_id_idx
  on public.restock_subscriptions(book_id);

create index if not exists sales_log_book_id_idx
  on public.sales_log(book_id)
  where book_id is not null;

alter function public.normalize_book_title(text) set search_path = 'public', 'pg_temp';
