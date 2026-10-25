-- Admin-only profit tracking. Historical sales_log.unit_cost stays untouched.
-- Old stock is divided across recorded batches by *estimated* FIFO opening
-- balance. Exact lot provenance starts with new sales after this migration.
create table if not exists private.book_profit_lot_opening (
  batch_id bigint primary key references public.web_book_batches(id) on delete restrict,
  opening_units integer not null check (opening_units >= 0),
  verified boolean not null default false,
  recorded_at timestamptz not null default now()
);

create table if not exists private.book_profit_sale_allocations (
  order_id uuid not null references public.orders(id) on delete cascade,
  item_index integer not null,
  unit_index integer not null,
  book_id uuid not null,
  batch_id bigint references public.web_book_batches(id) on delete restrict,
  unit_cost integer not null check (unit_cost >= 0),
  assigned_at timestamptz not null default now(),
  primary key (order_id, item_index, unit_index)
);
create index if not exists book_profit_sales_by_batch_idx
  on private.book_profit_sale_allocations(batch_id);

-- Prior purchases do not contain an item-by-item remaining-lot ledger.
-- Allocate current STOCK to newer batches first (FIFO assumption), and
-- explicitly mark those opening balances UNVERIFIED.
with lot_totals as (
  select wb.id, wb.book_id, wb.quantity, coalesce(b.stock,0) stock,
    coalesce(sum(wb.quantity) over (
      partition by wb.book_id
      order by wb.purchased_at desc, wb.id desc
      rows between unbounded preceding and 1 preceding
    ),0) newer_units
  from public.web_book_batches wb
  join public.books b on b.id=wb.book_id
)
insert into private.book_profit_lot_opening(batch_id,opening_units,verified)
select id, least(quantity,greatest(0,stock-newer_units))::integer, false
from lot_totals
on conflict(batch_id) do nothing;

-- Any batch created from now on gets its own untouched cost and quantity.
create or replace function private.book_profit_initialize_batch()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into private.book_profit_lot_opening(batch_id,opening_units,verified)
  values (new.id,new.quantity,true)
  on conflict(batch_id) do nothing;
  return new;
end;
$$;
drop trigger if exists book_profit_initialize_batch on public.web_book_batches;
create trigger book_profit_initialize_batch
after insert on public.web_book_batches for each row
execute function private.book_profit_initialize_batch();

-- New accepted/paid/shipping sales use frozen per-unit batch costs, not
-- the mutable books.cost_price. Existing historical sales are not rewritten.
-- Stable (order,item,unit) identity survives _rebuild_sales_log_for_order(),
-- which deletes and reinserts sales_log records when an order changes.
create or replace function private.book_profit_capture_sale()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_saved private.book_profit_sale_allocations%rowtype;
  v_batch_id bigint;
  v_cost integer;
begin
  if new.book_id is null then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.book_id::text, 20261026));

  select * into v_saved
  from private.book_profit_sale_allocations a
  where a.order_id=new.order_id and a.item_index=new.item_index
    and a.unit_index=new.unit_index;
  if found then
    -- Preserve the original sale's cost even if the book or batch changes.
    new.unit_cost:=v_saved.unit_cost;
    return new;
  end if;

  select bt.id, bt.unit_cost into v_batch_id, v_cost
  from public.web_book_batches bt
  join private.book_profit_lot_opening op on op.batch_id=bt.id
  where bt.book_id=new.book_id
    and bt.purchased_at <= coalesce(new.sold_at::date,current_date)
    and op.opening_units > (
      select count(*)
      from private.book_profit_sale_allocations a
      join public.orders o on o.id=a.order_id
      where a.batch_id=bt.id and o.status in ('accepted','paid','shipping')
    )
  order by bt.purchased_at asc,bt.id asc limit 1;

  -- Unrecorded opening stock cannot safely be assigned to a made-up batch.
  v_cost:=coalesce(v_cost,greatest(0,coalesce(new.unit_cost,0)));
  insert into private.book_profit_sale_allocations
    (order_id,item_index,unit_index,book_id,batch_id,unit_cost)
  values (new.order_id,new.item_index,new.unit_index,new.book_id,v_batch_id,v_cost);
  new.unit_cost:=v_cost;
  return new;
end;
$$;
drop trigger if exists book_profit_capture_sale on public.sales_log;
create trigger book_profit_capture_sale
before insert on public.sales_log for each row
execute function private.book_profit_capture_sale();

-- If a verified new lot is edited before it is sold, the quantity should
-- match the inventory entry. Never silently alter unverified historic lots.
create or replace function private.book_profit_batch_quantity_changed()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.quantity is distinct from old.quantity then
    update private.book_profit_lot_opening op
    set opening_units=new.quantity
    where op.batch_id=new.id and op.verified
      and not exists (
        select 1 from private.book_profit_sale_allocations a
        where a.batch_id=new.id
      );
  end if;
  return new;
end;
$$;
drop trigger if exists book_profit_batch_quantity_changed on public.web_book_batches;
create trigger book_profit_batch_quantity_changed
after update of quantity on public.web_book_batches for each row
execute function private.book_profit_batch_quantity_changed();

-- All financial data is returned by a separately verified admin-only RPC.
-- No direct SELECT privileges on private ledger data.
create or replace function public.admin_book_profit_report(p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  return jsonb_build_object(
    'books',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',b.id,'title',b.title,'category',b.category,
        'author',b.author,'stock',b.stock,'cost_price',b.cost_price,
        'sale_price',case when b.discount_percent>0
           and (b.discount_ends_at is null or b.discount_ends_at>now())
           then round(b.price*(100-b.discount_percent)/100.0)::int
           else b.price end,
        'image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url),
        'active',b.is_active
      ) order by b.title)
      from public.books b
    ),'[]'::jsonb),
    'batches',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',bt.id,'book_id',bt.book_id,'quantity',bt.quantity,
        'unit_cost',bt.unit_cost,'purchased_at',bt.purchased_at,
        'note',bt.note,'batch_group_id',bt.batch_group_id,
        'remaining',greatest(0,op.opening_units-coalesce(alloc.used,0)),
        'verified',op.verified
      ) order by bt.purchased_at,bt.id)
      from public.web_book_batches bt
      join private.book_profit_lot_opening op on op.batch_id=bt.id
      left join lateral (
        select count(*)::integer used
        from private.book_profit_sale_allocations a
        join public.orders o on o.id=a.order_id
        where a.batch_id=bt.id
          and o.status in ('accepted','paid','shipping')
      ) alloc on true
    ),'[]'::jsonb),
    'sales',coalesce((
      select jsonb_agg(jsonb_build_object(
        'book_id',s.book_id,'title',s.title,
        'unit_price',s.unit_price,'unit_cost',s.unit_cost,
        'sold_at',s.sold_at,'batch_id',a.batch_id,
        'source',s.source
      ) order by s.sold_at desc,s.id desc)
      from public.sales_log s
      left join private.book_profit_sale_allocations a
        on a.order_id=s.order_id
       and a.item_index=s.item_index and a.unit_index=s.unit_index
    ),'[]'::jsonb),
    'generated_at',now()
  );
end;
$$;

revoke all on private.book_profit_lot_opening from public,anon,authenticated;
revoke all on private.book_profit_sale_allocations from public,anon,authenticated;
revoke all on function public.admin_book_profit_report(text) from public,anon,authenticated;
grant execute on function public.admin_book_profit_report(text)
  to anon,authenticated,service_role;

comment on function public.admin_book_profit_report(text) is
 'Admin-only sales and batch profit; unverified opening balances are estimates; each new unit sale freezes its actual batch cost.';
