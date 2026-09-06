-- Muhajeer Books / Supabase schema
-- Supabase SQL Editor'da bir marta ishga tushiring.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author text not null default '',
  category text not null default 'Boshqa',
  description text not null default '',
  price integer not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  discount_percent integer not null default 0 check (discount_percent between 0 and 99),
  image_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  phone text not null,
  address text not null,
  delivery_type text not null,
  delivery_fee integer not null default 0 check (delivery_fee >= 0),
  subtotal integer not null check (subtotal >= 0),
  total integer not null check (total >= 0),
  status text not null default 'new' check (status in ('new', 'paid', 'shipping', 'done', 'cancelled')),
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists books_touch_updated_at on public.books;
create trigger books_touch_updated_at
before update on public.books
for each row execute function public.touch_updated_at();

drop trigger if exists orders_touch_updated_at on public.orders;
create trigger orders_touch_updated_at
before update on public.orders
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, 'customer')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.reserve_order_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  book_uuid uuid;
  qty integer;
  available integer;
begin
  for item in select * from jsonb_array_elements(new.items)
  loop
    book_uuid := (item ->> 'book_id')::uuid;
    qty := greatest(1, (item ->> 'quantity')::integer);

    select stock into available
    from public.books
    where id = book_uuid
    for update;

    if available is null then
      raise exception 'Kitob topilmadi: %', book_uuid;
    end if;

    if available < qty then
      raise exception 'Omborda yetarli kitob yo''q: %', book_uuid;
    end if;

    update public.books
      set stock = stock - qty
      where id = book_uuid;
  end loop;
  return new;
end;
$$;

drop trigger if exists reserve_stock_before_order on public.orders;
create trigger reserve_stock_before_order
before insert on public.orders
for each row execute function public.reserve_order_stock();

create or replace function public.sync_cancelled_order_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  book_uuid uuid;
  qty integer;
  available integer;
begin
  if old.status <> 'cancelled' and new.status = 'cancelled' then
    for item in select * from jsonb_array_elements(new.items)
    loop
      book_uuid := (item ->> 'book_id')::uuid;
      qty := greatest(1, (item ->> 'quantity')::integer);
      update public.books set stock = stock + qty where id = book_uuid;
    end loop;
  elsif old.status = 'cancelled' and new.status <> 'cancelled' then
    for item in select * from jsonb_array_elements(new.items)
    loop
      book_uuid := (item ->> 'book_id')::uuid;
      qty := greatest(1, (item ->> 'quantity')::integer);
      select stock into available from public.books where id = book_uuid for update;
      if available is null or available < qty then
        raise exception 'Buyurtmani qayta ochish uchun ombor yetarli emas: %', book_uuid;
      end if;
      update public.books set stock = stock - qty where id = book_uuid;
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_stock_on_order_status on public.orders;
create trigger sync_stock_on_order_status
before update of status on public.orders
for each row execute function public.sync_cancelled_order_stock();

alter table public.profiles enable row level security;
alter table public.books enable row level security;
alter table public.orders enable row level security;

create policy "users can read own profile"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.is_admin());

create policy "public can read active books"
on public.books for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy "admin can insert books"
on public.books for insert
to authenticated
with check (public.is_admin());

create policy "admin can update books"
on public.books for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admin can delete books"
on public.books for delete
to authenticated
using (public.is_admin());

create policy "public can create orders"
on public.orders for insert
to anon, authenticated
with check (status = 'new');

create policy "admin can read orders"
on public.orders for select
to authenticated
using (public.is_admin());

create policy "admin can update orders"
on public.orders for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into storage.buckets (id, name, public)
values ('book-covers', 'book-covers', true)
on conflict (id) do update set public = true;

create policy "public can view book covers"
on storage.objects for select
to public
using (bucket_id = 'book-covers');

create policy "admin can upload book covers"
on storage.objects for insert
to authenticated
with check (bucket_id = 'book-covers' and public.is_admin());

create policy "admin can update book covers"
on storage.objects for update
to authenticated
using (bucket_id = 'book-covers' and public.is_admin())
with check (bucket_id = 'book-covers' and public.is_admin());

create policy "admin can delete book covers"
on storage.objects for delete
to authenticated
using (bucket_id = 'book-covers' and public.is_admin());

-- BIRINCHI ADMINNI YOQISH:
-- 1) Supabase Authentication -> Users orqali email/parol bilan user yarating.
-- 2) Quyidagi emailni o'zingiznikiga almashtirib SQL Editor'da ishlating:
-- update public.profiles
-- set role = 'admin'
-- where id = (select id from auth.users where email = 'admin@example.com');
