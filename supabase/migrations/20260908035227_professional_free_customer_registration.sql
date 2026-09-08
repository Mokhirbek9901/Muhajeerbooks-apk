create table if not exists public.customer_contacts (
  phone_key text primary key,
  full_name text not null default '',
  phone text not null default '',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  visit_count integer not null default 1 check (visit_count >= 1)
);

alter table public.customer_contacts enable row level security;
revoke all on table public.customer_contacts from public, anon, authenticated;

create index if not exists customer_contacts_last_seen_idx
  on public.customer_contacts(last_seen_at desc);

create or replace function public._customer_phone_key(p_phone text)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if digits like '82%' then
    return digits;
  elsif digits like '0%' and length(digits) > 1 then
    return '82' || substring(digits from 2);
  end if;
  return digits;
end;
$$;
revoke all on function public._customer_phone_key(text) from public, anon, authenticated;

create or replace function public.customer_register_free(p_name text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
  clean_phone text := trim(coalesce(p_phone, ''));
  digits text := regexp_replace(clean_phone, '[^0-9]', '', 'g');
  key_value text;
begin
  if length(clean_name) < 2 or length(clean_name) > 80 then
    raise exception 'Ismni to‘liq kiriting';
  end if;
  if length(digits) < 9 or length(digits) > 15 then
    raise exception 'Telefon raqam noto‘g‘ri';
  end if;

  key_value := public._customer_phone_key(clean_phone);

  insert into public.customer_contacts(
    phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
  ) values (
    key_value, clean_name, clean_phone, now(), now(), 1
  )
  on conflict(phone_key) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    last_seen_at = now(),
    visit_count = public.customer_contacts.visit_count + 1;

  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.customer_register_free(text, text) from public;
grant execute on function public.customer_register_free(text, text) to anon, authenticated;

create or replace function public.sync_customer_contact_from_order()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := regexp_replace(trim(coalesce(new.customer_name, '')), '\s+', ' ', 'g');
  clean_phone text := trim(coalesce(new.phone, ''));
  digits text := regexp_replace(clean_phone, '[^0-9]', '', 'g');
  key_value text;
begin
  if length(clean_name) < 2 or length(digits) < 9 or length(digits) > 15 then
    return new;
  end if;

  key_value := public._customer_phone_key(clean_phone);
  insert into public.customer_contacts(
    phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
  ) values (
    key_value, clean_name, clean_phone, new.created_at, new.created_at, 1
  )
  on conflict(phone_key) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    first_seen_at = least(public.customer_contacts.first_seen_at, excluded.first_seen_at),
    last_seen_at = greatest(public.customer_contacts.last_seen_at, excluded.last_seen_at);
  return new;
end;
$$;
revoke all on function public.sync_customer_contact_from_order() from public, anon, authenticated;

drop trigger if exists orders_sync_customer_contact on public.orders;
create trigger orders_sync_customer_contact
after insert on public.orders
for each row execute function public.sync_customer_contact_from_order();

with ranked as (
  select
    public._customer_phone_key(phone) as phone_key,
    full_name,
    phone,
    created_at,
    last_seen_at,
    greatest(login_count, 1) as visit_count,
    row_number() over (
      partition by public._customer_phone_key(phone)
      order by last_seen_at desc, created_at desc
    ) as rn
  from public.profiles
  where role = 'customer'
    and length(regexp_replace(phone, '[^0-9]', '', 'g')) between 9 and 15
)
insert into public.customer_contacts(
  phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
)
select phone_key, coalesce(nullif(trim(full_name), ''), 'Muhajeer kitobxoni'), phone,
       created_at, last_seen_at, visit_count
from ranked
where rn = 1
on conflict(phone_key) do update set
  full_name = case
    when excluded.full_name <> 'Muhajeer kitobxoni' then excluded.full_name
    else public.customer_contacts.full_name
  end,
  phone = excluded.phone,
  first_seen_at = least(public.customer_contacts.first_seen_at, excluded.first_seen_at),
  last_seen_at = greatest(public.customer_contacts.last_seen_at, excluded.last_seen_at),
  visit_count = greatest(public.customer_contacts.visit_count, excluded.visit_count);

with ranked as (
  select
    public._customer_phone_key(phone) as phone_key,
    customer_name,
    phone,
    created_at,
    row_number() over (
      partition by public._customer_phone_key(phone)
      order by created_at desc
    ) as rn,
    min(created_at) over (partition by public._customer_phone_key(phone)) as first_seen,
    max(created_at) over (partition by public._customer_phone_key(phone)) as last_seen
  from public.orders
  where length(regexp_replace(phone, '[^0-9]', '', 'g')) between 9 and 15
)
insert into public.customer_contacts(
  phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
)
select phone_key, coalesce(nullif(trim(customer_name), ''), 'Muhajeer kitobxoni'), phone,
       first_seen, last_seen, 1
from ranked
where rn = 1
on conflict(phone_key) do update set
  full_name = case
    when excluded.full_name <> 'Muhajeer kitobxoni' then excluded.full_name
    else public.customer_contacts.full_name
  end,
  phone = excluded.phone,
  first_seen_at = least(public.customer_contacts.first_seen_at, excluded.first_seen_at),
  last_seen_at = greatest(public.customer_contacts.last_seen_at, excluded.last_seen_at);

create or replace function public.admin_user_stats(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  return jsonb_build_object(
    'total_users', (select count(*) from public.customer_contacts),
    'active_today', (select count(*) from public.customer_contacts where last_seen_at >= now()-interval '24 hours'),
    'active_7d', (select count(*) from public.customer_contacts where last_seen_at >= now()-interval '7 days'),
    'new_30d', (select count(*) from public.customer_contacts where first_seen_at >= now()-interval '30 days'),
    'total_installs', (select count(*) from public.app_installations),
    'active_installs_today', (select count(*) from public.app_installations where last_seen_at >= now()-interval '24 hours'),
    'total_orders', (select count(*) from public.orders),
    'open_orders', (select count(*) from public.orders where status in ('new','accepted','paid','shipping')),
    'completed_orders', (select count(*) from public.orders where status='done'),
    'completed_revenue', (select coalesce(sum(total),0) from public.orders where status='done')
  );
end;
$$;

create or replace function public.admin_list_customers(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', c.phone_key,
        'full_name', c.full_name,
        'phone', c.phone,
        'created_at', c.first_seen_at,
        'last_seen_at', c.last_seen_at,
        'last_login_at', c.last_seen_at,
        'login_count', c.visit_count,
        'order_count', coalesce(x.order_count,0),
        'spent', coalesce(x.spent,0)
      ) order by c.last_seen_at desc
    )
    from public.customer_contacts c
    left join lateral (
      select count(*)::int as order_count,
             coalesce(sum(case when o.status='done' then o.total else 0 end),0)::bigint as spent
      from public.orders o
      where public._customer_phone_key(o.phone)=c.phone_key
    ) x on true
  ), '[]'::jsonb);
end;
$$;
