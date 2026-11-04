-- PRIVATE ADMIN ORDER NOTES: never stored on public.orders or customer-visible records.
create table if not exists private.admin_order_notes (
  order_id uuid primary key references public.orders(id) on delete cascade,
  note text not null default '',
  updated_at timestamptz not null default now(),
  constraint private_order_note_length check (char_length(note) <= 1000)
);
alter table private.admin_order_notes enable row level security;
revoke all on table private.admin_order_notes from public, anon, authenticated;
revoke all on table private.admin_order_notes from service_role;
create or replace function public.admin_order_private_notes(p_secret text)
returns jsonb language plpgsql security definer set search_path to ''
as $body$
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 return coalesce((select jsonb_object_agg(n.order_id::text,n.note)
                  from private.admin_order_notes n),'{}'::jsonb);
end;
$body$;
create or replace function public.admin_order_private_note_save(
  p_secret text, p_id uuid, p_note text
) returns text language plpgsql security definer set search_path to ''
as $body$
declare cleaned text:=trim(coalesce(p_note,''));
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_id is null or not exists(select 1 from public.orders where id=p_id) then
    raise exception 'Buyurtma topilmadi';
 end if;
 if char_length(cleaned)>1000 then raise exception 'Izoh juda uzun (1000 belgi).'; end if;
 if cleaned='' then
    delete from private.admin_order_notes where order_id=p_id;
 else
    insert into private.admin_order_notes(order_id,note,updated_at)
    values(p_id,cleaned,now())
    on conflict(order_id) do update
      set note=excluded.note,updated_at=now();
 end if;
 return cleaned;
end;
$body$;
revoke all on function public.admin_order_private_notes(text) from public,anon,authenticated;
revoke all on function public.admin_order_private_note_save(text,uuid,text) from public,anon,authenticated;
grant execute on function public.admin_order_private_notes(text) to anon,authenticated,service_role;
grant execute on function public.admin_order_private_note_save(text,uuid,text) to anon,authenticated,service_role;

-- PREORDER DELIVERY DATE RANGE; keep legacy arrival_note for shipped clients.
alter table public.web_preorder_settings
add column if not exists arrival_start date,
add column if not exists arrival_end date;
alter table public.web_preorder_settings
drop constraint if exists web_preorder_arrival_range_order;
alter table public.web_preorder_settings
add constraint web_preorder_arrival_range_order check (
  (arrival_start is null and arrival_end is null) or
  (arrival_start is not null and arrival_end is not null and arrival_start <= arrival_end)
);
CREATE OR REPLACE FUNCTION public.admin_web_preorder_manage(p_secret text, p_action text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.web_preorder_settings%rowtype; r public.web_preorder_requests%rowtype;
 enabled_value boolean; arrival text; amount integer; batch integer; target text; note_value text;
 range_provided boolean; start_date date; end_date date;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='settings' then return public.web_preorder_config();
 elsif p_action='save' then
  enabled_value:=(p_payload->>'enabled')::boolean; arrival:=trim(coalesce(p_payload->>'arrival_note',''));
  amount:=(p_payload->>'deposit_amount')::integer; batch:=(p_payload->>'batch_quantity')::integer;
  -- New admin versions supply two exact dates. Existing mobile versions
  -- continue to read arrival_note, which now contains the display interval.
  -- Older admins saving legacy text preserve existing date columns.
  range_provided := p_payload ? 'arrival_start' OR p_payload ? 'arrival_end';
  IF range_provided THEN
    IF coalesce(jsonb_typeof(p_payload->'arrival_start'),'null') <> 'string'
       OR coalesce(jsonb_typeof(p_payload->'arrival_end'),'null') <> 'string' THEN
      RAISE EXCEPTION 'Boshlanish va tugash sanalarini tanlang.';
    END IF;
    start_date := (p_payload->>'arrival_start')::date;
    end_date := (p_payload->>'arrival_end')::date;
    IF start_date IS NULL OR end_date IS NULL OR end_date < start_date
       OR end_date > start_date + 730 THEN
      RAISE EXCEPTION 'Kelish sanalari oralig‘ini tekshiring.';
    END IF;
    arrival := to_char(start_date,'YYYY.MM.DD') || ' ~ ' ||
               to_char(end_date,'YYYY.MM.DD');
  END IF;
  if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
    (enabled_value and arrival='') or amount not between 5000 and 10000000 or batch not between 0 and 100000 then
   raise exception 'Sana, avans va sonni tekshiring.'; end if;
  select * into s from public.web_preorder_settings where id for update;
  if (p_payload->>'revision')::bigint is distinct from s.revision then
   raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.'; end if;
  update public.web_preorder_settings
  set enabled=enabled_value,arrival_note=arrival,deposit_amount=amount,
    batch_quantity=batch,revision=revision+1,updated_at=now(),
    arrival_start=case when range_provided then start_date else arrival_start end,
    arrival_end=case when range_provided then end_date else arrival_end end
  where id;
  return public.web_preorder_config();
 elsif p_action='list' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select req.*,
    (select e.delivery_state from private.web_preorder_events e where e.preorder_id=req.id and e.audience='customer' order by version desc limit 1) as notification_state,
    (select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'created_at',h.created_at,'message',h.body) order by h.version desc),'[]') from private.web_preorder_events h where h.preorder_id=req.id and h.audience='customer') as history
    from public.web_preorder_requests req
    where not exists (select 1 from private.admin_preorder_hidden h
      where h.source='web' and h.order_id=req.id::text)
    order by req.created_at desc,req.id desc
      limit least(200,greatest(1,coalesce((p_payload->>'limit')::integer,200)))
      offset greatest(0,coalesce((p_payload->>'offset')::integer,0))) x),'[]');
 elsif p_action='status' then
  target:=p_payload->>'status'; note_value:=trim(coalesce(p_payload->>'note',''));
  if target is null or target not in ('waiting','accepted','arrived','cancelled') or length(note_value)>500 then raise exception 'Noto‘g‘ri holat'; end if;
  select * into r from public.web_preorder_requests q where q.id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Buyurtma topilmadi'; end if;
  if r.status=target then return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',true); end if;
  if (p_payload->>'version')::integer is distinct from r.status_version then raise exception 'Holat boshqa oynada o‘zgargan. Ro‘yxatni yangilang.'; end if;
  if not ((r.status='waiting' and target in ('accepted','cancelled')) or
    (r.status='accepted' and target in ('arrived','cancelled')) or
    (r.status='arrived' and target='cancelled') or
    (r.status='cancelled' and target='waiting')) then raise exception 'Avval buyurtmani qabul qiling yoki bekor qilingan buyurtmani qayta oching.'; end if;
  if r.status='cancelled' and target='waiting' and exists(
    select 1 from public.web_preorder_requests newer
     where newer.id<>r.id and newer.phone=r.phone
       and newer.status in ('waiting','accepted','arrived')
       and ( (r.book_id is not null and newer.book_id=r.book_id)
         or (r.book_id is null and newer.book_id is null and newer.book_title=r.book_title))
  ) then
    raise exception 'Bu mijoz allaqachon yangi faol zakaz yuborgan. Eski bekor qilinganini qayta ochmang.';
  end if;
  if target in ('cancelled','waiting') and length(note_value)<3 then raise exception 'Sababini yozing (kamida 3 belgi).'; end if;
  update public.web_preorder_requests q set status=target,status_note=note_value,status_version=q.status_version+1,updated_at=now() where q.id=r.id returning * into r;
  return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',false,'inbox_created',true);
 end if;
 raise exception 'Noto‘g‘ri amal';
end;
$function$


