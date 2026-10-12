-- A book replenished in the warehouse belongs among the newest arrivals.
-- Keep created_at immutable; the restock timestamp does not change price history.
alter table public.books
  add column if not exists restocked_at timestamptz;

-- Reconstruct only historical replenishments for which the timestamp is known.
-- updated_at is NOT safe to backfill (sales and edits change it as well).
update public.books b
set restocked_at = history.last_restock
from (
  select book_id, max(restock_event_at) as last_restock
  from public.restock_sms_queue
  where restock_event_at is not null
  group by book_id
) history
where b.id = history.book_id
  and b.stock > 0
  and (b.restocked_at is null or b.restocked_at < history.last_restock);

create or replace function public.set_book_restock_date()
returns trigger language plpgsql
set search_path = public, pg_temp
as $fn$
begin
  if new.stock > old.stock and new.stock > 0 then
    new.restocked_at := clock_timestamp();
  end if;
  return new;
end;
$fn$;

drop trigger if exists books_restock_date on public.books;
create trigger books_restock_date
before update of stock on public.books
for each row
when (new.stock > old.stock and new.stock > 0)
execute function public.set_book_restock_date();

-- Extend the existing secure customer catalog RPC allowlist without exposing
-- cost_price or changing its authentication and role permissions.
do $rebuild$
declare
  statement text;
  old_fragment text := '''created_at'',b.created_at,''updated_at'',b.updated_at';
  new_fragment text := '''created_at'',b.created_at,''restocked_at'',b.restocked_at,''updated_at'',b.updated_at';
begin
  statement := pg_get_functiondef('public.customer_catalog_delta(timestamptz)'::regprocedure);
  if strpos(statement, new_fragment) <> 0 then
    return;
  end if;
  if strpos(statement, old_fragment) = 0 then
    raise exception 'customer_catalog_delta allowlist has changed; please review migration';
  end if;
  execute replace(statement, old_fragment, new_fragment);
end
$rebuild$;
