-- Additive multi-book web requests; preserve all existing business records.
create table if not exists private.web_preorder_backup_20261021 as
select now() backed_up_at,
 (select jsonb_agg(to_jsonb(r)) from public.web_preorder_requests r) requests,
 (select jsonb_agg(to_jsonb(s)) from public.web_preorder_settings s) settings,
 (select jsonb_agg(to_jsonb(e)) from private.web_preorder_events e) events,
 (select jsonb_agg(pg_get_functiondef(p.oid)) from pg_proc p where p.oid in
 ('public.web_preorder_submit(jsonb)'::regprocedure,'public.admin_web_preorder_manage(text,text,jsonb)'::regprocedure)) functions;
alter table private.web_preorder_backup_20261021 enable row level security;
revoke all on private.web_preorder_backup_20261021 from public,anon,authenticated;

alter table public.web_preorder_requests add column request_items jsonb not null default '[]'::jsonb
 check(jsonb_typeof(request_items)='array');
alter table public.web_preorder_requests drop constraint web_preorder_requests_quantity_check;
alter table public.web_preorder_requests add constraint web_preorder_requests_quantity_check
 check(quantity between 1 and 100000);

-- Separate endpoint: installed native clients retain their existing single-book contract.
create function public.web_preorder_submit_multi(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 s public.web_preorder_settings%rowtype; old public.web_preorder_requests%rowtype;
 rid uuid:=(p_request->>'id')::uuid;
 cname text:=trim(p_request->>'customer_name');
 phone_value text:=regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
 proof text:=p_request->>'payment_proof_path';
 total bigint:=(p_request->>'deposit_amount')::bigint;
 item jsonb; normalized jsonb:='[]'; title_value text; image_value text; qty integer;
 units bigint:=0; summary text;
begin
 if rid is null or coalesce(length(cname),0) not between 2 and 80 or
   phone_value !~ '^010[0-9]{8}$' or jsonb_typeof(p_request->'items') is distinct from 'array' then
   raise exception 'Ism, telefon va kitoblarni tekshiring.'; end if;
 if jsonb_array_length(p_request->'items')=0 then raise exception 'Kamida bitta kitob kiriting.'; end if;
 for item in select value from jsonb_array_elements(p_request->'items') loop
  title_value:=trim(item->>'book_title'); image_value:=item->>'book_image_path'; qty:=(item->>'quantity')::integer;
  if coalesce(length(title_value),0) not between 2 and 160 or qty is null or qty not between 1 and 20 or
   image_value is null or image_value !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') then
   raise exception 'Har bir kitobning nomi, rasmi va miqdorini tekshiring.'; end if;
  units:=units+qty;
  normalized:=normalized||jsonb_build_array(jsonb_build_object('book_title',title_value,'book_image_path',image_value,'quantity',qty));
 end loop;
 if units>100000 or total is null or total>2147483647 then raise exception 'So‘rov juda katta. Kitoblarni alohida so‘rovlarga ajrating.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
 select * into old from public.web_preorder_requests r where r.id=rid;
 if found then
  if old.phone is distinct from phone_value or old.customer_name is distinct from cname or
   old.request_items is distinct from normalized or old.payment_proof_path is distinct from proof or
   old.deposit_amount is distinct from total then raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.'; end if;
  return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
 end if;
 select * into s from public.web_preorder_settings where id for share;
 if not s.enabled or trim(s.arrival_note)='' then raise exception 'Oldindan buyurtma qabuli yopiq. Avans yubormang.'; end if;
 if (p_request->>'revision')::bigint is distinct from s.revision or total is distinct from s.deposit_amount::bigint*units then
  raise exception 'Sana yoki avans o‘zgargan. Shartlarni qayta tekshiring.'; end if;
 if proof is null or proof !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
  not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof) or
  exists(select 1 from jsonb_array_elements(normalized) i where not exists
   (select 1 from storage.objects where bucket_id='web-preorder-assets' and name=i->>'book_image_path')) then
  raise exception 'Barcha kitob rasmlari va jami avans chekini yuklang.'; end if;
 summary:=case when jsonb_array_length(normalized)=1 then normalized->0->>'book_title'
  else left(normalized->0->>'book_title',130)||' + '||(jsonb_array_length(normalized)-1)||' turdagi kitob' end;
 insert into public.web_preorder_requests(id,customer_name,phone,book_title,book_image_path,payment_proof_path,
  quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,request_items)
 values(rid,cname,phone_value,summary,normalized->0->>'book_image_path',proof,units::integer,s.deposit_amount,total::integer,
  s.arrival_note,s.revision,normalized);
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false,'item_count',jsonb_array_length(normalized));
exception when unique_violation then
 raise exception 'Bu avans cheki avval yuborilgan. Administrator bilan tekshiring.';
end;
$$;
revoke all on function public.web_preorder_submit_multi(jsonb) from public,anon,authenticated;
grant execute on function public.web_preorder_submit_multi(jsonb) to service_role;

create or replace function public.admin_web_preorder_manage(p_secret text,p_action text,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.web_preorder_settings%rowtype; r public.web_preorder_requests%rowtype;
 enabled_value boolean; arrival text; amount integer; batch integer; target text; note_value text;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='settings' then return public.web_preorder_config();
 elsif p_action='save' then
  enabled_value:=(p_payload->>'enabled')::boolean; arrival:=trim(coalesce(p_payload->>'arrival_note',''));
  amount:=(p_payload->>'deposit_amount')::integer; batch:=(p_payload->>'batch_quantity')::integer;
  if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
    (enabled_value and arrival='') or amount not between 5000 and 10000000 or batch not between 0 and 100000 then
   raise exception 'Sana, avans va sonni tekshiring.'; end if;
  select * into s from public.web_preorder_settings where id for update;
  if (p_payload->>'revision')::bigint is distinct from s.revision then
   raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.'; end if;
  update public.web_preorder_settings set enabled=enabled_value,arrival_note=arrival,deposit_amount=amount,
   batch_quantity=batch,revision=revision+1,updated_at=now() where id;
  return public.web_preorder_config();
 elsif p_action='list' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select req.*,
    (select e.delivery_state from private.web_preorder_events e where e.preorder_id=req.id and e.audience='customer' order by version desc limit 1) as notification_state,
    (select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'created_at',h.created_at,'message',h.body) order by h.version desc),'[]') from private.web_preorder_events h where h.preorder_id=req.id and h.audience='customer') as history
    from public.web_preorder_requests req order by req.created_at desc,req.id desc
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
  if target in ('cancelled','waiting') and length(note_value)<3 then raise exception 'Sababini yozing (kamida 3 belgi).'; end if;
  update public.web_preorder_requests q set status=target,status_note=note_value,status_version=q.status_version+1,updated_at=now() where q.id=r.id returning * into r;
  return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',false,'inbox_created',true);
 end if;
 raise exception 'Noto‘g‘ri amal';
end;
$$;
