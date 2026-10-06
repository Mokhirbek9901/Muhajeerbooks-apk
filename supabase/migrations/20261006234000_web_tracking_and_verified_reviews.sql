-- Web-only customer experience support: parcel tracking and verified reviews.
-- Mobile clients keep using the existing customer_order_statuses RPC.

alter table public.orders
  add column if not exists carrier text not null default '',
  add column if not exists tracking_number text not null default '',
  add column if not exists tracking_updated_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_carrier_check'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_carrier_check
      check (carrier in ('','cj','epost','lotte','hanjin','logen','other'));
  end if;
end $$;

create table if not exists public.book_reviews (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  reviewer_name text not null default '',
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(trim(comment)) between 2 and 600),
  is_approved boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id, book_id)
);

create index if not exists book_reviews_book_created_idx
  on public.book_reviews(book_id, created_at desc)
  where is_approved = true;

alter table public.book_reviews enable row level security;
revoke all on table public.book_reviews from public, anon, authenticated;
grant all on table public.book_reviews to service_role;

create or replace function public.customer_order_statuses_v2(p_ids uuid[])
returns table(
  id uuid,
  status text,
  stock_reserved boolean,
  updated_at timestamptz,
  customer_accept_note text,
  carrier text,
  tracking_number text,
  tracking_updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id,o.status,o.stock_reserved,o.updated_at,o.customer_accept_note,
         coalesce(o.carrier,''),coalesce(o.tracking_number,''),o.tracking_updated_at
  from public.orders o
  where o.id = any(coalesce(p_ids,array[]::uuid[]))
  order by o.updated_at desc
  limit 50
$$;
revoke execute on function public.customer_order_statuses_v2(uuid[]) from public, anon, authenticated;
grant execute on function public.customer_order_statuses_v2(uuid[]) to service_role;

create or replace function public.admin_update_order_tracking(
  p_secret text, p_id uuid, p_carrier text, p_tracking_number text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_carrier text := lower(trim(coalesce(p_carrier,'')));
  v_tracking text := regexp_replace(coalesce(p_tracking_number,''), '[^0-9A-Za-z-]', '', 'g');
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  if v_carrier not in ('','cj','epost','lotte','hanjin','logen','other') then
    raise exception 'Pochta turi noto‘g‘ri';
  end if;
  if char_length(v_tracking) > 80 then raise exception 'Kuzatuv raqami juda uzun'; end if;
  if not exists(select 1 from public.orders where id=p_id) then raise exception 'Buyurtma topilmadi'; end if;
  update public.orders
     set carrier=v_carrier,
         tracking_number=v_tracking,
         tracking_updated_at=case when v_tracking='' then null else now() end,
         updated_at=now()
   where id=p_id;
end;
$$;
revoke execute on function public.admin_update_order_tracking(text,uuid,text,text) from public, anon, authenticated;
grant execute on function public.admin_update_order_tracking(text,uuid,text,text) to service_role;

create or replace function public.customer_book_reviews(p_book_id uuid)
returns table(
  id uuid, book_id uuid, reviewer_name text, rating smallint,
  comment text, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id,r.book_id,r.reviewer_name,r.rating,r.comment,r.created_at
  from public.book_reviews r
  where r.book_id=p_book_id and r.is_approved=true
  order by r.created_at desc
  limit 100
$$;
revoke execute on function public.customer_book_reviews(uuid) from public, anon, authenticated;
grant execute on function public.customer_book_reviews(uuid) to service_role;

create or replace function public.customer_book_review_submit(
  p_order_id uuid, p_phone text, p_book_id uuid, p_rating integer, p_comment text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_phone_key text := public._customer_phone_key(p_phone);
  v_comment text := trim(coalesce(p_comment,''));
  v_name text;
  v_id uuid;
begin
  if v_phone_key='' then raise exception 'Telefon raqami noto‘g‘ri'; end if;
  if p_rating<1 or p_rating>5 then raise exception 'Baho 1–5 oralig‘ida bo‘lsin'; end if;
  if char_length(v_comment)<2 or char_length(v_comment)>600 then
    raise exception 'Sharh 2–600 belgi oralig‘ida bo‘lsin';
  end if;

  select o.* into v_order
  from public.orders o
  where o.id=p_order_id
    and o.source='app'
    and public._customer_phone_key(o.phone)=v_phone_key
    and o.status in ('accepted','paid','shipping')
  limit 1;

  if v_order.id is null then raise exception 'Tasdiqlangan xarid topilmadi'; end if;
  if not exists (
    select 1
    from jsonb_array_elements(coalesce(v_order.items,'[]'::jsonb)) item
    where coalesce(item->>'book_id',item->>'id','')=p_book_id::text
  ) then raise exception 'Bu kitob ushbu buyurtmada topilmadi'; end if;

  v_name := split_part(trim(coalesce(v_order.customer_name,'Muhajeer kitobxoni')), ' ', 1);
  if v_name='' then v_name := 'Muhajeer kitobxoni'; end if;

  insert into public.book_reviews(book_id,order_id,reviewer_name,rating,comment,is_approved)
  values(p_book_id,p_order_id,left(v_name,80),p_rating,v_comment,true)
  on conflict(order_id,book_id)
  do update set rating=excluded.rating, comment=excluded.comment,
                reviewer_name=excluded.reviewer_name, is_approved=true, updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.customer_book_review_submit(uuid,text,uuid,integer,text) from public, anon, authenticated;
grant execute on function public.customer_book_review_submit(uuid,text,uuid,integer,text) to service_role;
