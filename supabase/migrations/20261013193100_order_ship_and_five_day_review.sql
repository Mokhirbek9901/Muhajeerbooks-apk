-- Automatic shipment push and once-only review reminder five days after dispatch.
create extension if not exists pg_cron with schema pg_catalog;
alter table public.orders add column if not exists shipped_at timestamptz;
alter table public.orders add column if not exists review_reminded_at timestamptz;

create or replace function private.record_shipped_at()
returns trigger language plpgsql set search_path=public,pg_temp as $fn$
begin
 if new.status='shipping' and old.status is distinct from 'shipping' then
  new.shipped_at:=coalesce(new.shipped_at,clock_timestamp());
 end if;
 return new;
end $fn$;
drop trigger if exists orders_record_shipped_at on public.orders;
create trigger orders_record_shipped_at
 before update of status on public.orders
 for each row execute function private.record_shipped_at();

-- Reuse existing authenticated Railway Web Push webhook on dispatch.
do $block$
declare def text;
begin
 def:=pg_get_functiondef('private.notify_app_order_push()'::regprocedure);
 if strpos(def, 'v_event := ''accepted'';')=0 then
  raise exception 'Order webhook changed; migration requires manual review';
 end if;
 if strpos(def, 'v_event := ''shipping'';')=0 then
  execute replace(def, 'v_event := ''accepted'';',
    'v_event := ''accepted'';'||chr(10)||
    '  elsif tg_op=''UPDATE'' and new.status=''shipping'' and old.status is distinct from new.status then'||chr(10)||
    '    v_event := ''shipping'';');
 end if;
end $block$;

create or replace function private.queue_due_book_review_requests(p_limit integer default 50)
returns integer language plpgsql security definer
set search_path=public,private,net,pg_temp as $fn$
declare o public.orders%rowtype; event_secret text; queued integer:=0;
begin
 select cfg.event_secret into event_secret from private.push_event_config cfg where cfg.id=true;
 for o in
  select * from public.orders
  where status='shipping' and source='app'
    and shipped_at is not null
    and shipped_at<=now()-interval '4 days'
    and review_reminded_at is null
    and length(regexp_replace(coalesce(phone,''),'[^0-9]','','g'))>=8
  order by shipped_at
  limit least(greatest(coalesce(p_limit,50),1),250)
  for update skip locked
 loop
  insert into public.customer_push_messages
    (phone,title,body,kind,order_number,order_id,sent_at)
  values (o.phone,'📚 Kitobingiz haqida fikr bildiring',
    'Buyurtma #'||coalesce(o.display_order_number,o.order_number,0)||
    'dagi kitoblar sizga yoqdimi? Mening buyurtmalarim bo‘limida baho va sharh qoldiring.',
    'review_reminder',coalesce(o.display_order_number,o.order_number),o.id,now());
  update public.orders set review_reminded_at=now() where id=o.id;
  queued:=queued+1;
  if coalesce(event_secret,'')<>'' then
   perform net.http_post(
    url:='https://muhajeer-books-live-production.up.railway.app/api/push/order-event',
    body:=jsonb_build_object('event','review_reminder','order_id',o.id,
      'order_number',coalesce(o.display_order_number,o.order_number,0),
      'phone',o.phone),
    headers:=jsonb_build_object('Content-Type','application/json',
      'X-Muhajeer-Push-Secret',event_secret),
    timeout_milliseconds:=5000);
  end if;
 end loop;
 return queued;
end $fn$;
revoke all on function private.queue_due_book_review_requests(integer)
 from public,anon,authenticated;
grant execute on function private.queue_due_book_review_requests(integer)
 to service_role;

do $cron$
begin
 if not exists(select 1 from cron.job where jobname='muhajeer_order_review_five_days') then
  perform cron.schedule('muhajeer_order_review_five_days','15 3 * * *',
    'select private.queue_due_book_review_requests(250);');
 end if;
end $cron$;
