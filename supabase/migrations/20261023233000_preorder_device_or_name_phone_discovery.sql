-- Unify native and web preorder discovery without exposing a payment proof.
-- Installation binding is attached at web-order submission; old records may be
-- DISCOVERED by exact name and phone but never modified through this lookup.
alter table public.web_preorder_requests add column if not exists install_id text;
create index if not exists web_preorder_by_install_id
  on public.web_preorder_requests(install_id,created_at desc)
  where install_id is not null;
CREATE OR REPLACE FUNCTION public.web_preorder_submit(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 c jsonb; old public.web_preorder_requests%rowtype;
 rid uuid := (p_request->>'id')::uuid;
 bid uuid := nullif(p_request->>'book_id','')::uuid;
 qty integer := (p_request->>'quantity')::integer;
 title text := trim(p_request->>'book_title'); cname text := trim(p_request->>'customer_name');
 phone text := regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
 book_path text := coalesce(p_request->>'book_image_path','');
 proof_path text := p_request->>'payment_proof_path';
 total integer := (p_request->>'deposit_amount')::integer; per_book integer;
begin
 if nullif(trim(coalesce(p_request->>'install_id','')),'') is not null and
    length(trim(p_request->>'install_id')) not between 12 and 120 then
    raise exception 'Qurilma identifikatori noto‘g‘ri'; end if;
 if rid is null or qty is null or qty not between 1 and 20 or
   coalesce(length(cname),0) not between 2 and 80 or phone !~ '^010[0-9]{8}$' then
   raise exception 'Ism, telefon va miqdorni tekshiring.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
 select * into old from public.web_preorder_requests r where r.id=rid;
 if found then
   if old.phone is distinct from phone or old.quantity is distinct from qty or
     old.customer_name is distinct from cname or old.book_id is distinct from bid or
     (bid is null and (old.book_title is distinct from title or old.book_image_path is distinct from book_path)) or
     old.payment_proof_path is distinct from proof_path or old.deposit_amount is distinct from total then
     raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.'; end if;
   return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
 end if;
 if bid is null then
   perform 1 from public.web_preorder_settings where id for share;
   c:=public.web_preorder_config();
 else
   perform 1 from public.books where id=bid for share;
   c:=public.web_preorder_book_config(bid);
   title:=c->>'book_title'; book_path:='';
 end if;
 if c is null or (c->>'enabled')::boolean is not true or trim(coalesce(c->>'arrival_note',''))='' then
   raise exception 'Bu kitob uchun oldindan buyurtma qabuli hozircha yopiq. Avans yubormang.'; end if;
 if coalesce(length(title),0) not between 2 and 160 then raise exception 'Kitob nomini tekshiring.'; end if;
 if (bid is null and (p_request->>'revision')::bigint is distinct from (c->>'revision')::bigint) or
    (bid is not null and p_request->>'terms_token' is distinct from c->>'terms_token') then
   raise exception 'Sana yoki avans o‘zgargan. Shartlarni yangilab, qayta tekshiring.'; end if;
 if total is null or total % qty <> 0 then raise exception 'Avans summasini tekshiring.'; end if;
 per_book:=total/qty;
 if per_book not between (c->>'deposit_amount')::integer and coalesce((c->>'deposit_max')::integer,(c->>'deposit_amount')::integer) then
   raise exception 'Avans summasini tekshiring.'; end if;
 if proof_path is null or proof_path !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
    not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof_path) or
    (bid is null and (book_path !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') or
      not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=book_path))) then
   raise exception 'Kitob rasmi va to‘lov chekini yuklang.'; end if;
 insert into public.web_preorder_requests(id,book_id,customer_name,phone,book_title,book_image_path,
  book_image_url,payment_proof_path,quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,terms_token,install_id)
 values(rid,bid,cname,phone,title,book_path,coalesce(c->>'book_image_url',''),proof_path,qty,per_book,total,
  c->>'arrival_note',(c->>'revision')::bigint,coalesce(c->>'terms_token',''),nullif(trim(p_request->>'install_id'),''));
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false);
exception when unique_violation then
 raise exception 'Bu chek bo‘yicha buyurtma avval qabul qilingan. Administrator bilan tekshiring.';
end;
$function$
;
CREATE OR REPLACE FUNCTION public.web_preorder_submit_multi(p_request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if nullif(trim(coalesce(p_request->>'install_id','')),'') is not null and
    length(trim(p_request->>'install_id')) not between 12 and 120 then
    raise exception 'Qurilma identifikatori noto‘g‘ri'; end if;
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
  quantity,deposit_per_book,deposit_amount,arrival_note,settings_revision,request_items,install_id)
 values(rid,cname,phone_value,summary,normalized->0->>'book_image_path',proof,units::integer,s.deposit_amount,total::integer,
  s.arrival_note,s.revision,normalized,nullif(trim(p_request->>'install_id'),''));
 return jsonb_build_object('id',rid,'status','waiting','duplicate',false,'item_count',jsonb_array_length(normalized));
exception when unique_violation then
 raise exception 'Bu avans cheki avval yuborilgan. Administrator bilan tekshiring.';
end;
$function$
;

create or replace function public.customer_preorder_discovery(
  p_install_id text, p_name text default '', p_phone text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_records jsonb;
        v_id text:=trim(coalesce(p_install_id,''));
        v_name text:=lower(regexp_replace(trim(coalesce(p_name,'')),'\s+',' ','g'));
        v_phone text:=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
        v_contact_ok boolean;
begin
  if length(v_id) not between 12 and 120 then
    raise exception 'Qurilma ma’lumotlari noto‘g‘ri';
  end if;
  v_contact_ok := length(v_name) between 2 and 80 and
    v_phone ~ '^010[0-9]{8}$';
  select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc),'[]'::jsonb)
    into v_records
  from (
    select 'native'::text as source,p.id::text as id,
      coalesce(b.title,'Kitob') as title,p.status,p.quantity,p.created_at,
      case when p.install_id=v_id then 'device' else 'contact' end as ownership
    from public.preorders p
    left join public.books b on b.id=p.book_id
    where (p.install_id=v_id or
       (v_contact_ok and lower(regexp_replace(trim(p.customer_name),'\s+',' ','g'))=v_name
        and regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=v_phone))
      and not exists(select 1 from private.admin_preorder_hidden a
       where a.source='native' and a.order_id=p.id::text)
    union all
    select 'web'::text,w.id::text as id,w.book_title,w.status,w.quantity,w.created_at,
      case when w.install_id=v_id then 'device' else 'contact' end
    from public.web_preorder_requests w
    where (w.install_id=v_id or
       (v_contact_ok and lower(regexp_replace(trim(w.customer_name),'\s+',' ','g'))=v_name
        and regexp_replace(coalesce(w.phone,''),'[^0-9]','','g')=v_phone))
      and not exists(select 1 from private.admin_preorder_hidden a
        where a.source='web' and a.order_id=w.id::text)
    order by created_at desc limit 80
  ) v;
  return v_records;
end;
$$;
revoke all on function public.customer_preorder_discovery(text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_preorder_discovery(text,text,text)
  to service_role;

create or replace function public.customer_preorder_activity_list(
  p_install_id text,p_name text default '',p_phone text default '',
  p_limit integer default 60
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_rows jsonb;
        v_id text:=trim(coalesce(p_install_id,''));
        v_name text:=lower(regexp_replace(trim(coalesce(p_name,'')),'\s+',' ','g'));
        v_phone text:=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
        v_contact_ok boolean;
begin
  if length(v_id) not between 12 and 120 or
     p_limit is null or p_limit not between 1 and 100 then
    raise exception 'Qurilma ma’lumotlari yoki limit noto‘g‘ri';
  end if;
  v_contact_ok:=length(v_name) between 2 and 80 and v_phone~'^010[0-9]{8}$';
  select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
    into v_rows from (
    select 'native:'||e.id::text as id,'native'::text as source,
      p.id::text as preorder_id,e.event_type as event_type,e.title,
      e.message,e.created_at
    from private.customer_preorder_events e
    join public.preorders p on p.id=e.preorder_id
    where (p.install_id=v_id or
      (v_contact_ok and lower(regexp_replace(trim(p.customer_name),'\s+',' ','g'))=v_name
       and regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=v_phone))
      and not exists(select 1 from private.admin_preorder_hidden a
       where a.source='native' and a.order_id=p.id::text)
    union all
    select 'web:'||e.id::text as id,'web'::text as source,
      w.id::text as preorder_id,e.status as event_type,
      case e.status when 'accepted' then 'Oldindan zakazingiz qabul qilindi ✅'
        when 'arrived' then 'Kitobingiz keldi 📚'
        when 'cancelled' then 'Oldindan zakaz bekor qilindi'
        else 'Oldindan zakaz yuborildi' end as title,
      'Zakazingiz holati o‘zgardi. «Oldindan zakazlarim» bo‘limini oching.'::text as message,
      e.created_at
    from private.web_preorder_events e
    join public.web_preorder_requests w on w.id=e.preorder_id
    where e.audience='customer' and
      (w.install_id=v_id or
       (v_contact_ok and lower(regexp_replace(trim(w.customer_name),'\s+',' ','g'))=v_name
       and regexp_replace(coalesce(w.phone,''),'[^0-9]','','g')=v_phone))
      and not exists(select 1 from private.admin_preorder_hidden a
       where a.source='web' and a.order_id=w.id::text)
    order by created_at desc,id desc limit p_limit
  ) v;
  return v_rows;
end;
$$;
revoke all on function public.customer_preorder_activity_list(text,text,text,integer)
  from public,anon,authenticated;
grant execute on function public.customer_preorder_activity_list(text,text,text,integer)
  to service_role;
