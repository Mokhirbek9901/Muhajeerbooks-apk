-- Additive, web-only preorder flow. Existing orders, stock and finance are untouched.
create table public.web_preorder_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  arrival_note text not null default '',
  deposit_amount integer not null default 5000 check (deposit_amount between 5000 and 10000000),
  batch_quantity integer not null default 0 check (batch_quantity between 0 and 100000),
  revision bigint not null default 1,
  updated_at timestamptz not null default now()
);
insert into public.web_preorder_settings(id) values(true);
create table public.web_preorder_requests (
  id uuid primary key,
  customer_name text not null,
  phone text not null,
  book_title text not null,
  book_image_path text not null,
  payment_proof_path text not null,
  quantity integer not null check (quantity between 1 and 20),
  deposit_per_book integer not null check (deposit_per_book >= 5000),
  deposit_amount integer not null,
  arrival_note text not null,
  settings_revision bigint not null,
  status text not null default 'waiting' check (status in ('waiting','accepted','arrived','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.web_preorder_settings enable row level security;
alter table public.web_preorder_requests enable row level security;
revoke all on public.web_preorder_settings,public.web_preorder_requests from anon,authenticated;
grant all on public.web_preorder_settings,public.web_preorder_requests to service_role;
create index web_preorder_requests_created_idx on public.web_preorder_requests(created_at desc);
create unique index web_preorder_receipt_digest_unique on public.web_preorder_requests
  ((substring(payment_proof_path from 'proof-([a-f0-9]{64})')));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('web-preorder-assets','web-preorder-assets',false,2097152,array['image/jpeg','image/png','image/webp']);

create function public.web_preorder_config() returns jsonb
language sql security definer set search_path = '' as $$
  select to_jsonb(s) - 'id' from public.web_preorder_settings s where id;
$$;

create function public.web_preorder_submit(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  s public.web_preorder_settings%rowtype;
  old public.web_preorder_requests%rowtype;
  rid uuid := (p_request->>'id')::uuid;
  qty integer := (p_request->>'quantity')::integer;
  title text := trim(p_request->>'book_title');
  cname text := trim(p_request->>'customer_name');
  phone text := regexp_replace(coalesce(p_request->>'phone',''),'[^0-9]','','g');
  book_path text := p_request->>'book_image_path';
  proof_path text := p_request->>'payment_proof_path';
begin
  if rid is null or qty is null or qty not between 1 and 20 or
    coalesce(length(title),0) not between 2 and 160 or
    coalesce(length(cname),0) not between 2 and 80 or phone !~ '^010[0-9]{8}$' then
    raise exception 'Kitob, ism, telefon va miqdorni tekshiring.';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,0));
  select * into old from public.web_preorder_requests where id=rid;
  if found then
    if old.phone is distinct from phone or old.book_title is distinct from title or old.quantity is distinct from qty or
      old.customer_name is distinct from cname or old.book_image_path is distinct from book_path or
      old.payment_proof_path is distinct from proof_path then
      raise exception 'Buyurtma identifikatori boshqa so‘rovga tegishli.';
    end if;
    return jsonb_build_object('id',old.id,'status',old.status,'duplicate',true);
  end if;
  select * into s from public.web_preorder_settings where id for share;
  if not s.enabled or trim(s.arrival_note)='' then
    raise exception 'Oldindan buyurtma qabuli yopiq. Avans yuborgan bo‘lsangiz, administratorga murojaat qiling.';
  end if;
  if (p_request->>'revision')::bigint is distinct from s.revision or
     (p_request->>'deposit_amount')::integer is distinct from s.deposit_amount*qty then
    raise exception 'Sana yoki avans o‘zgargan. Shartlarni yangilab, qayta tekshiring.';
  end if;
  if book_path is null or proof_path is null or
    book_path !~ ('^'||rid::text||'/book-[a-f0-9]{64}\.(jpg|png|webp)$') or
    proof_path !~ ('^'||rid::text||'/proof-[a-f0-9]{64}\.(jpg|png|webp)$') or
    not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=book_path) or
    not exists(select 1 from storage.objects where bucket_id='web-preorder-assets' and name=proof_path) then
    raise exception 'Kitob rasmi va to‘lov chekini yuklang.';
  end if;
  insert into public.web_preorder_requests(id,customer_name,phone,book_title,
    book_image_path,payment_proof_path,quantity,deposit_per_book,deposit_amount,
    arrival_note,settings_revision)
  values(rid,cname,phone,title,book_path,proof_path,qty,s.deposit_amount,
    s.deposit_amount*qty,s.arrival_note,s.revision);
  return jsonb_build_object('id',rid,'status','waiting','duplicate',false);
exception when unique_violation then
  raise exception 'Bu chek bo‘yicha buyurtma avval qabul qilingan. Administrator bilan tekshiring.';
end;
$$;

create function public.admin_web_preorder_manage(p_secret text,p_action text,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  s public.web_preorder_settings%rowtype;
  enabled_value boolean;
  arrival text;
  amount integer;
  batch integer;
begin
  if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
  if p_action='settings' then return public.web_preorder_config();
  elsif p_action='save' then
    enabled_value := (p_payload->>'enabled')::boolean;
    arrival := trim(coalesce(p_payload->>'arrival_note',''));
    amount := (p_payload->>'deposit_amount')::integer;
    batch := (p_payload->>'batch_quantity')::integer;
    if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
      (enabled_value and arrival='') or amount not between 5000 and 10000000 or
      batch not between 0 and 100000 then raise exception 'Sana, avans va sonni tekshiring.'; end if;
    select * into s from public.web_preorder_settings where id for update;
    if (p_payload->>'revision')::bigint is distinct from s.revision then
      raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.';
    end if;
    update public.web_preorder_settings set enabled=enabled_value,arrival_note=arrival,
      deposit_amount=amount,batch_quantity=batch,revision=revision+1,updated_at=now() where id;
    return public.web_preorder_config();
  elsif p_action='list' then
    return coalesce((select jsonb_agg(to_jsonb(r)) from
      (select * from public.web_preorder_requests order by created_at desc limit 200) r),'[]');
  elsif p_action='status' then
    if p_payload->>'status' not in ('waiting','accepted','arrived','cancelled') then
      raise exception 'Noto‘g‘ri holat'; end if;
    update public.web_preorder_requests set status=p_payload->>'status',updated_at=now()
      where id=(p_payload->>'id')::uuid;
    if not found then raise exception 'Buyurtma topilmadi'; end if;
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'Noto‘g‘ri amal';
end;
$$;
revoke all on function public.web_preorder_config(),public.web_preorder_submit(jsonb),
  public.admin_web_preorder_manage(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.web_preorder_config(),public.web_preorder_submit(jsonb),
  public.admin_web_preorder_manage(text,text,jsonb) to service_role;
