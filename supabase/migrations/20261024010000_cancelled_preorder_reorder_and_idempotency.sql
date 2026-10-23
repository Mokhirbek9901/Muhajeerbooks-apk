-- Cancelled preorders are history, NOT a reason to block a new purchase.
-- Prevent active duplicates and silent overwrites; keep all old deposits.
create unique index if not exists preorders_one_active_device_book
 on public.preorders(book_id,install_id)
 where status in ('waiting','contacted','accepted','arrived');

CREATE OR REPLACE FUNCTION public.customer_preorder_submit(p_install_id text, p_book_id uuid, p_customer_name text DEFAULT ''::text, p_phone text DEFAULT ''::text, p_quantity integer DEFAULT 1, p_deposit_amount integer DEFAULT 0, p_payment_proof_path text DEFAULT ''::text, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.preorders; prior public.preorders%rowtype; v_min integer; v_max integer; safe_install text:=trim(p_install_id);
begin
  if length(trim(p_install_id))<12 or p_quantity is null or p_quantity<1 or p_quantity>20 then raise exception 'Invalid preorder'; end if;
  select preorder_deposit_min,preorder_deposit_max into v_min,v_max
  from public.books where id=p_book_id and is_active=true and preorder_enabled=true;
  if not found then raise exception 'Oldindan sotuv yopiq'; end if;
  if p_deposit_amount is null or p_deposit_amount < v_min*p_quantity or p_deposit_amount > v_max*p_quantity then
    raise exception 'Jami avans %–% won bo‘lishi kerak',v_min*p_quantity,v_max*p_quantity;
  end if;
  if trim(coalesce(p_payment_proof_path,''))='' then raise exception 'To‘lov cheki kerak'; end if;
  -- A cancelled request is historical and never blocks a fresh booking.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('preorder:'||safe_install||':'||p_book_id::text,0));
  select * into prior from public.preorders
    where book_id=p_book_id and install_id=safe_install
      and status in ('waiting','contacted','accepted','arrived')
    order by id desc limit 1 for update;
  if found then
    if prior.status='waiting'
      and prior.payment_proof_path=left(trim(p_payment_proof_path),500)
      and prior.deposit_amount=p_deposit_amount and prior.quantity=p_quantity
      and prior.phone=left(trim(p_phone),32)
      and prior.customer_name=left(trim(p_customer_name),80)
      and coalesce(prior.note,'')=left(trim(coalesce(p_note,'')),500) then
      return jsonb_build_object('id',prior.id,'status',prior.status,
        'deposit_amount',prior.deposit_amount,'duplicate',true);
    end if;
    raise exception 'Bu kitobga faol zakazingiz bor. Oldindan zakazlarim bo‘limini tekshiring. Bekor qilingach qayta zakaz berish mumkin.';
  end if;
  insert into public.preorders(book_id,install_id,customer_name,phone,quantity,status,deposit_amount,payment_proof_path,note)
  values(p_book_id,safe_install,left(trim(p_customer_name),80),left(trim(p_phone),32),p_quantity,'waiting',
         p_deposit_amount,left(trim(p_payment_proof_path),500),left(trim(p_note),500))
  returning * into r;
  return jsonb_build_object('id',r.id,'status',r.status,'deposit_amount',r.deposit_amount,'duplicate',false);
exception when unique_violation then
  raise exception 'Bu kitob uchun faol oldindan zakaz bor. Oldindan zakazlarim bo‘limini tekshiring.';
end $function$;

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
   if old.status='cancelled' then
     raise exception 'Bu bekor qilingan eski zakaz. Yangi buyurtma uchun yangi zakaz sahifasini oching. Eski avans avtomatik ko‘chirilmaydi.';
   end if;
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
 if exists(select 1 from public.web_preorder_requests w
    where substring(w.payment_proof_path from 'proof-([a-f0-9]{64})')=
          substring(proof_path from 'proof-([a-f0-9]{64})')
      and w.status='cancelled') then
    raise exception 'Eski bekor qilingan zakazdagi chekni qayta yubormang. Yangi zakaz uchun yangi avans cheki kerak. Oldingi avansni ko‘chirish uchun admin tasdig‘i talab qilinadi.';
  end if;
  raise exception 'Bu avans cheki boshqa buyurtmada ishlatilgan. Yangi to‘lov chekini yuboring yoki mavjud zakazni tekshiring.';
end;
$function$;

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
   if old.status='cancelled' then
     raise exception 'Bu bekor qilingan eski zakaz. Yangi buyurtma uchun yangi zakaz sahifasini oching. Eski avans avtomatik ko‘chirilmaydi.';
   end if;
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
 if exists(select 1 from public.web_preorder_requests w
    where substring(w.payment_proof_path from 'proof-([a-f0-9]{64})')=
          substring(proof from 'proof-([a-f0-9]{64})')
      and w.status='cancelled') then
    raise exception 'Eski bekor qilingan zakazdagi chekni qayta yubormang. Yangi zakaz uchun yangi avans cheki kerak. Oldingi avansni ko‘chirish uchun admin tasdig‘i talab qilinadi.';
  end if;
  raise exception 'Bu avans cheki boshqa buyurtmada ishlatilgan. Yangi to‘lov chekini yuboring yoki mavjud zakazni tekshiring.';
end;
$function$;

revoke all on function public.customer_preorder_submit(text,uuid,text,text,integer,integer,text,text) from public,anon,authenticated;
grant execute on function public.customer_preorder_submit(text,uuid,text,text,integer,integer,text,text) to service_role;
revoke all on function public.web_preorder_submit(jsonb) from public,anon,authenticated;
grant execute on function public.web_preorder_submit(jsonb) to service_role;
revoke all on function public.web_preorder_submit_multi(jsonb) from public,anon,authenticated;
grant execute on function public.web_preorder_submit_multi(jsonb) to service_role;
