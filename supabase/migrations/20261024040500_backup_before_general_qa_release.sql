-- Point-in-time private backup before batch editor and preorder QA hardening.
-- Database-only; no customer-facing tables or stock are modified.
create table if not exists private.qa_backup_20261024_batches (
  table_name text not null,
  source_id text not null,
  snapshot jsonb not null,
  captured_at timestamptz not null default now(),
  primary key(table_name,source_id)
);
revoke all on private.qa_backup_20261024_batches from public,anon,authenticated;

insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_book_batches',id::text,to_jsonb(src) from public.web_book_batches src
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_batch_imports',id::text,to_jsonb(src) from public.web_batch_imports src
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_batch_groups',id::text,to_jsonb(src) from public.web_batch_groups src
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_finance_batch_groups',id::text,to_jsonb(src) from public.web_finance_batch_groups src
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_batch_transport_links',finance_expense_id::text,to_jsonb(src) from public.web_batch_transport_links src
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'book_stock_cost',id::text,jsonb_build_object('id',id,
  'stock',stock,'cost_price',cost_price,'updated_at',updated_at)
from public.books
on conflict do nothing;
insert into private.qa_backup_20261024_batches(table_name,source_id,snapshot)
select 'web_preorder_checkout',preorder_id::text,to_jsonb(src)
from private.web_preorder_checkout src
on conflict do nothing;

create table if not exists private.qa_backup_20261024_functions (
  function_signature text primary key,
  original_definition text not null,
  captured_at timestamptz not null default now()
);
revoke all on private.qa_backup_20261024_functions from public,anon,authenticated;
insert into private.qa_backup_20261024_functions(function_signature,original_definition)
select p.oid::regprocedure::text,pg_get_functiondef(p.oid)
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
 'customer_web_preorder_checkout','admin_web_preorder_checkout_confirm',
 'admin_web_batch_picker_data','admin_web_bulk_batch_save')
on conflict do nothing;
