-- Optional four-digit PIN profile without SMS. Existing customers retain their
-- checkout flow; cross-device profile restoration REQUIRES this PIN.
-- WARNING: a name/phone match alone never proves number ownership.
create table if not exists private.customer_pin_profiles (
  phone_key text primary key,
  display_phone text not null,
  full_name text not null,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists private.customer_pin_devices (
  phone_key text not null references private.customer_pin_profiles(phone_key) on delete cascade,
  install_id text not null,
  linked_at timestamptz not null default now(),
  primary key(phone_key, install_id)
);
create table if not exists private.customer_pin_sessions (
  token_hash text primary key,
  phone_key text not null references private.customer_pin_profiles(phone_key) on delete cascade,
  install_id text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists pin_sessions_phone on private.customer_pin_sessions(phone_key,expires_at);
create index if not exists pin_devices_install on private.customer_pin_devices(install_id);
revoke all on private.customer_pin_profiles,private.customer_pin_devices,
  private.customer_pin_sessions from public,anon,authenticated;

create or replace function private.pin_start_session(
  p_phone_key text, p_install_id text
) returns text language plpgsql security definer set search_path=''
as $$
declare tok text:=encode(extensions.gen_random_bytes(32),'hex');
begin
  insert into private.customer_pin_sessions(token_hash,phone_key,install_id,expires_at)
  values(encode(extensions.digest(tok,'sha256'),'hex'),p_phone_key,p_install_id,now()+interval '30 days');
  insert into private.customer_pin_devices(phone_key,install_id)
  values(p_phone_key,p_install_id) on conflict do nothing;
  return tok;
end;
$$;
revoke all on function private.pin_start_session(text,text) from public,anon,authenticated;

create or replace function public.customer_pin_register(
  p_name text, p_phone text, p_pin text, p_install_id text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text; n text; p text; tok text;
begin
  n:=regexp_replace(trim(coalesce(p_name,'')),'\s+',' ','g');
  p:=trim(coalesce(p_phone,''));
  k:=public._customer_phone_key(p);
  if k='' or length(n) not between 2 and 80
    or coalesce(p_pin,'') !~ '^[0-9]{4}
    or length(trim(coalesce(p_install_id,''))) not between 12 and 120 then
      raise exception 'Ism, raqam, PIN yoki qurilma noto‘g‘ri';
  end if;
  if exists(select 1 from private.customer_pin_profiles where phone_key=k) then
    raise exception 'Bu raqam uchun PIN allaqachon bor. Kirish bo‘limidan foydalaning';
  end if;
  insert into private.customer_pin_profiles(phone_key,display_phone,full_name,pin_hash)
    values(k,p,n,extensions.crypt(p_pin,extensions.gen_salt('bf',11)));
  tok:=private.pin_start_session(k,trim(p_install_id));
  return jsonb_build_object('name',n,'phone',p,'session',tok,
    'expires_in_days',30);
end;
$$;
revoke all on function public.customer_pin_register(text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_register(text,text,text,text) to service_role;

create or replace function public.customer_pin_login(
  p_phone text, p_pin text, p_install_id text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=public._customer_phone_key(trim(coalesce(p_phone,'')));
        r private.customer_pin_profiles%rowtype; tok text;
begin
  if k='' or p_pin !~ '^[0-9]{4}$'
    or length(trim(coalesce(p_install_id,''))) not between 12 and 120 then
    raise exception 'Telefon yoki PIN noto‘g‘ri';
  end if;
  select * into r from private.customer_pin_profiles where phone_key=k for update;
  if not found then raise exception 'PIN noto‘g‘ri yoki hisob topilmadi'; end if;
  if r.locked_until is not null and r.locked_until>now() then
    return jsonb_build_object('error','Ko‘p urinish bo‘ldi. 30 daqiqadan keyin urinib ko‘ring','locked',true);
  end if;
  if extensions.crypt(p_pin,r.pin_hash)<>r.pin_hash then
    update private.customer_pin_profiles
      set failed_attempts=case when r.failed_attempts>=4 then 0 else r.failed_attempts+1 end,
          locked_until=case when r.failed_attempts>=4 then now()+interval '30 minutes'
                else null end
      where phone_key=k;
    -- Return an error instead of raising: a raised exception would roll
    -- back failed_attempts and allow unlimited four-digit PIN guessing.
    return jsonb_build_object('error','PIN noto‘g‘ri yoki hisob topilmadi',
      'locked',r.failed_attempts>=4);
  end if;
  update private.customer_pin_profiles
    set failed_attempts=0,locked_until=null where phone_key=k;
  tok:=private.pin_start_session(k,trim(p_install_id));
  return jsonb_build_object('name',r.full_name,'phone',r.display_phone,
    'session',tok,'expires_in_days',30);
end;
$$;
revoke all on function public.customer_pin_login(text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_login(text,text,text) to service_role;

create or replace function private.pin_session_phone(p_token text)
returns text language plpgsql security definer set search_path=''
as $$
declare k text;
begin
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then return null; end if;
 select s.phone_key into k from private.customer_pin_sessions s
 where s.token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
   and s.expires_at>now();
 return k;
end;
$$;
revoke all on function private.pin_session_phone(text) from public,anon,authenticated;

create or replace function public.customer_pin_profile(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session);
        n text; phone text;
begin
 if k is null then raise exception 'Kirish muddati tugagan. PIN bilan qayta kiring'; end if;
 select full_name,display_phone into n,phone
   from private.customer_pin_profiles where phone_key=k;
 return jsonb_build_object('name',n,'phone',phone,'valid',true);
end;
$$;
revoke all on function public.customer_pin_profile(text) from public,anon,authenticated;
grant execute on function public.customer_pin_profile(text) to service_role;

create or replace function public.customer_pin_logout(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if p_session ~ '^[a-f0-9]{64}$' then
   delete from private.customer_pin_sessions
    where token_hash=encode(extensions.digest(p_session,'sha256'),'hex');
 end if;
 return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.customer_pin_logout(text) from public,anon,authenticated;
grant execute on function public.customer_pin_logout(text) to service_role;

-- Cross-device read-only status summaries are scoped to devices previously
-- connected by a valid PIN login, NEVER to name + phone matches alone.
create or replace function public.customer_pin_preorders(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session); rows jsonb;
begin
 if k is null then raise exception 'PIN bilan kirishingiz kerak'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc),'[]'::jsonb)
 into rows from (
   select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
     p.status,p.quantity,p.created_at,'pin'::text ownership
     from public.preorders p
     left join public.books b on b.id=p.book_id
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=p.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='native' and h.order_id=p.id::text)
   union all
   select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,
     w.created_at,'pin'::text
     from public.web_preorder_requests w
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=w.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='web' and h.order_id=w.id::text)
   order by created_at desc limit 100
 ) t;
 return rows;
end;
$$;
revoke all on function public.customer_pin_preorders(text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_preorders(text) to service_role;

-- Critical: old mobile clients could enumerate preorder states by typing
-- someone else's name+phone. Preserve only same-installation discovery;
-- cross-device lookup must use the long random session token.
create or replace function public.customer_preorder_discovery(
 p_install_id text,p_name text default '',p_phone text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_records jsonb;
begin
 if length(v_id) not between 12 and 120 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
 into v_records from (
  select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
   p.status,p.quantity,p.created_at,'device'::text ownership
   from public.preorders p left join public.books b on b.id=p.book_id
   where p.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,w.created_at,
   'device'::text
   from public.web_preorder_requests w
   where w.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='web' and a.order_id=w.id::text)
  order by created_at desc limit 80
 ) x;
 return v_records;
end;
$$;
revoke all on function public.customer_preorder_discovery(text,text,text)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_discovery(text,text,text) to service_role;

create or replace function public.customer_preorder_activity_list(
 p_install_id text,p_name text default '',p_phone text default '',
 p_limit integer default 60
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_rows jsonb;
begin
 if length(v_id) not between 12 and 120 or
   coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
 into v_rows from (
  select 'native:'||e.id::text id,'native'::text source,p.id::text preorder_id,
   e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=v_id and not exists(
    select 1 from private.admin_preorder_hidden a
    where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web:'||e.id::text,'web'::text,w.id::text,
   e.status,case e.status when 'accepted' then 'Zakazingiz qabul qilindi ✅'
     when 'arrived' then 'Kitobingiz keldi 📚'
     else 'Oldindan zakaz holati o‘zgardi' end,
   'Oldindan zakazlarim bo‘limini tekshiring.'::text,e.created_at
   from private.web_preorder_events e
   join public.web_preorder_requests w on w.id=e.preorder_id
   where e.audience='customer' and w.install_id=v_id
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
  order by created_at desc,id desc limit p_limit
 ) v;
 return v_rows;
end;
$$;
revoke all on function public.customer_preorder_activity_list(text,text,text,integer)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_activity_list(text,text,text,integer) to service_role;

    or length(trim(coalesce(p_install_id,''))) not between 12 and 120 then
      raise exception 'Ism, raqam, PIN yoki qurilma noto‘g‘ri';
  end if;
  if exists(select 1 from private.customer_pin_profiles where phone_key=k) then
    raise exception 'Bu raqam uchun PIN allaqachon bor. Kirish bo‘limidan foydalaning';
  end if;
  insert into private.customer_pin_profiles(phone_key,display_phone,full_name,pin_hash)
    values(k,p,n,extensions.crypt(p_pin,extensions.gen_salt('bf',11)));
  tok:=private.pin_start_session(k,trim(p_install_id));
  return jsonb_build_object('name',n,'phone',p,'session',tok,
    'expires_in_days',30);
end;
$$;
revoke all on function public.customer_pin_register(text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_register(text,text,text,text) to service_role;

create or replace function public.customer_pin_login(
  p_phone text, p_pin text, p_install_id text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=public._customer_phone_key(trim(coalesce(p_phone,'')));
        r private.customer_pin_profiles%rowtype; tok text;
begin
  if k='' or coalesce(p_pin,'') !~ '^[0-9]{4}
    or length(trim(coalesce(p_install_id,''))) not between 12 and 120 then
    raise exception 'Telefon yoki PIN noto‘g‘ri';
  end if;
  select * into r from private.customer_pin_profiles where phone_key=k for update;
  if not found then raise exception 'PIN noto‘g‘ri yoki hisob topilmadi'; end if;
  if r.locked_until is not null and r.locked_until>now() then
    return jsonb_build_object('error','Ko‘p urinish bo‘ldi. 30 daqiqadan keyin urinib ko‘ring','locked',true);
  end if;
  if extensions.crypt(p_pin,r.pin_hash)<>r.pin_hash then
    update private.customer_pin_profiles
      set failed_attempts=case when r.failed_attempts>=4 then 0 else r.failed_attempts+1 end,
          locked_until=case when r.failed_attempts>=4 then now()+interval '30 minutes'
                else null end
      where phone_key=k;
    -- Return an error instead of raising: a raised exception would roll
    -- back failed_attempts and allow unlimited four-digit PIN guessing.
    return jsonb_build_object('error','PIN noto‘g‘ri yoki hisob topilmadi',
      'locked',r.failed_attempts>=4);
  end if;
  update private.customer_pin_profiles
    set failed_attempts=0,locked_until=null where phone_key=k;
  tok:=private.pin_start_session(k,trim(p_install_id));
  return jsonb_build_object('name',r.full_name,'phone',r.display_phone,
    'session',tok,'expires_in_days',30);
end;
$$;
revoke all on function public.customer_pin_login(text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_login(text,text,text) to service_role;

create or replace function private.pin_session_phone(p_token text)
returns text language plpgsql security definer set search_path=''
as $$
declare k text;
begin
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then return null; end if;
 select s.phone_key into k from private.customer_pin_sessions s
 where s.token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
   and s.expires_at>now();
 return k;
end;
$$;
revoke all on function private.pin_session_phone(text) from public,anon,authenticated;

create or replace function public.customer_pin_profile(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session);
        n text; phone text;
begin
 if k is null then raise exception 'Kirish muddati tugagan. PIN bilan qayta kiring'; end if;
 select full_name,display_phone into n,phone
   from private.customer_pin_profiles where phone_key=k;
 return jsonb_build_object('name',n,'phone',phone,'valid',true);
end;
$$;
revoke all on function public.customer_pin_profile(text) from public,anon,authenticated;
grant execute on function public.customer_pin_profile(text) to service_role;

create or replace function public.customer_pin_logout(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if p_session ~ '^[a-f0-9]{64}$' then
   delete from private.customer_pin_sessions
    where token_hash=encode(extensions.digest(p_session,'sha256'),'hex');
 end if;
 return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.customer_pin_logout(text) from public,anon,authenticated;
grant execute on function public.customer_pin_logout(text) to service_role;

-- Cross-device read-only status summaries are scoped to devices previously
-- connected by a valid PIN login, NEVER to name + phone matches alone.
create or replace function public.customer_pin_preorders(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session); rows jsonb;
begin
 if k is null then raise exception 'PIN bilan kirishingiz kerak'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc),'[]'::jsonb)
 into rows from (
   select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
     p.status,p.quantity,p.created_at,'pin'::text ownership
     from public.preorders p
     left join public.books b on b.id=p.book_id
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=p.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='native' and h.order_id=p.id::text)
   union all
   select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,
     w.created_at,'pin'::text
     from public.web_preorder_requests w
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=w.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='web' and h.order_id=w.id::text)
   order by created_at desc limit 100
 ) t;
 return rows;
end;
$$;
revoke all on function public.customer_pin_preorders(text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_preorders(text) to service_role;

-- Critical: old mobile clients could enumerate preorder states by typing
-- someone else's name+phone. Preserve only same-installation discovery;
-- cross-device lookup must use the long random session token.
create or replace function public.customer_preorder_discovery(
 p_install_id text,p_name text default '',p_phone text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_records jsonb;
begin
 if length(v_id) not between 12 and 120 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
 into v_records from (
  select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
   p.status,p.quantity,p.created_at,'device'::text ownership
   from public.preorders p left join public.books b on b.id=p.book_id
   where p.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,w.created_at,
   'device'::text
   from public.web_preorder_requests w
   where w.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='web' and a.order_id=w.id::text)
  order by created_at desc limit 80
 ) x;
 return v_records;
end;
$$;
revoke all on function public.customer_preorder_discovery(text,text,text)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_discovery(text,text,text) to service_role;

create or replace function public.customer_preorder_activity_list(
 p_install_id text,p_name text default '',p_phone text default '',
 p_limit integer default 60
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_rows jsonb;
begin
 if length(v_id) not between 12 and 120 or
   coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
 into v_rows from (
  select 'native:'||e.id::text id,'native'::text source,p.id::text preorder_id,
   e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=v_id and not exists(
    select 1 from private.admin_preorder_hidden a
    where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web:'||e.id::text,'web'::text,w.id::text,
   e.status,case e.status when 'accepted' then 'Zakazingiz qabul qilindi ✅'
     when 'arrived' then 'Kitobingiz keldi 📚'
     else 'Oldindan zakaz holati o‘zgardi' end,
   'Oldindan zakazlarim bo‘limini tekshiring.'::text,e.created_at
   from private.web_preorder_events e
   join public.web_preorder_requests w on w.id=e.preorder_id
   where e.audience='customer' and w.install_id=v_id
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
  order by created_at desc,id desc limit p_limit
 ) v;
 return v_rows;
end;
$$;
revoke all on function public.customer_preorder_activity_list(text,text,text,integer)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_activity_list(text,text,text,integer) to service_role;

    or length(trim(coalesce(p_install_id,''))) not between 12 and 120 then
    raise exception 'Telefon yoki PIN noto‘g‘ri';
  end if;
  select * into r from private.customer_pin_profiles where phone_key=k for update;
  if not found then raise exception 'PIN noto‘g‘ri yoki hisob topilmadi'; end if;
  if r.locked_until is not null and r.locked_until>now() then
    return jsonb_build_object('error','Ko‘p urinish bo‘ldi. 30 daqiqadan keyin urinib ko‘ring','locked',true);
  end if;
  if extensions.crypt(p_pin,r.pin_hash)<>r.pin_hash then
    update private.customer_pin_profiles
      set failed_attempts=case when r.failed_attempts>=4 then 0 else r.failed_attempts+1 end,
          locked_until=case when r.failed_attempts>=4 then now()+interval '30 minutes'
                else null end
      where phone_key=k;
    -- Return an error instead of raising: a raised exception would roll
    -- back failed_attempts and allow unlimited four-digit PIN guessing.
    return jsonb_build_object('error','PIN noto‘g‘ri yoki hisob topilmadi',
      'locked',r.failed_attempts>=4);
  end if;
  update private.customer_pin_profiles
    set failed_attempts=0,locked_until=null where phone_key=k;
  tok:=private.pin_start_session(k,trim(p_install_id));
  return jsonb_build_object('name',r.full_name,'phone',r.display_phone,
    'session',tok,'expires_in_days',30);
end;
$$;
revoke all on function public.customer_pin_login(text,text,text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_login(text,text,text) to service_role;

create or replace function private.pin_session_phone(p_token text)
returns text language plpgsql security definer set search_path=''
as $$
declare k text;
begin
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then return null; end if;
 select s.phone_key into k from private.customer_pin_sessions s
 where s.token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
   and s.expires_at>now();
 return k;
end;
$$;
revoke all on function private.pin_session_phone(text) from public,anon,authenticated;

create or replace function public.customer_pin_profile(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session);
        n text; phone text;
begin
 if k is null then raise exception 'Kirish muddati tugagan. PIN bilan qayta kiring'; end if;
 select full_name,display_phone into n,phone
   from private.customer_pin_profiles where phone_key=k;
 return jsonb_build_object('name',n,'phone',phone,'valid',true);
end;
$$;
revoke all on function public.customer_pin_profile(text) from public,anon,authenticated;
grant execute on function public.customer_pin_profile(text) to service_role;

create or replace function public.customer_pin_logout(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if p_session ~ '^[a-f0-9]{64}$' then
   delete from private.customer_pin_sessions
    where token_hash=encode(extensions.digest(p_session,'sha256'),'hex');
 end if;
 return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.customer_pin_logout(text) from public,anon,authenticated;
grant execute on function public.customer_pin_logout(text) to service_role;

-- Cross-device read-only status summaries are scoped to devices previously
-- connected by a valid PIN login, NEVER to name + phone matches alone.
create or replace function public.customer_pin_preorders(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare k text:=private.pin_session_phone(p_session); rows jsonb;
begin
 if k is null then raise exception 'PIN bilan kirishingiz kerak'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc),'[]'::jsonb)
 into rows from (
   select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
     p.status,p.quantity,p.created_at,'pin'::text ownership
     from public.preorders p
     left join public.books b on b.id=p.book_id
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=p.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='native' and h.order_id=p.id::text)
   union all
   select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,
     w.created_at,'pin'::text
     from public.web_preorder_requests w
     where exists(select 1 from private.customer_pin_devices d
      where d.phone_key=k and d.install_id=w.install_id)
      and not exists(select 1 from private.admin_preorder_hidden h
       where h.source='web' and h.order_id=w.id::text)
   order by created_at desc limit 100
 ) t;
 return rows;
end;
$$;
revoke all on function public.customer_pin_preorders(text)
  from public,anon,authenticated;
grant execute on function public.customer_pin_preorders(text) to service_role;

-- Critical: old mobile clients could enumerate preorder states by typing
-- someone else's name+phone. Preserve only same-installation discovery;
-- cross-device lookup must use the long random session token.
create or replace function public.customer_preorder_discovery(
 p_install_id text,p_name text default '',p_phone text default ''
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_records jsonb;
begin
 if length(v_id) not between 12 and 120 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
 into v_records from (
  select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
   p.status,p.quantity,p.created_at,'device'::text ownership
   from public.preorders p left join public.books b on b.id=p.book_id
   where p.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,w.created_at,
   'device'::text
   from public.web_preorder_requests w
   where w.install_id=v_id and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='web' and a.order_id=w.id::text)
  order by created_at desc limit 80
 ) x;
 return v_records;
end;
$$;
revoke all on function public.customer_preorder_discovery(text,text,text)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_discovery(text,text,text) to service_role;

create or replace function public.customer_preorder_activity_list(
 p_install_id text,p_name text default '',p_phone text default '',
 p_limit integer default 60
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id text:=trim(coalesce(p_install_id,'')); v_rows jsonb;
begin
 if length(v_id) not between 12 and 120 or
   coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
 into v_rows from (
  select 'native:'||e.id::text id,'native'::text source,p.id::text preorder_id,
   e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=v_id and not exists(
    select 1 from private.admin_preorder_hidden a
    where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web:'||e.id::text,'web'::text,w.id::text,
   e.status,case e.status when 'accepted' then 'Zakazingiz qabul qilindi ✅'
     when 'arrived' then 'Kitobingiz keldi 📚'
     else 'Oldindan zakaz holati o‘zgardi' end,
   'Oldindan zakazlarim bo‘limini tekshiring.'::text,e.created_at
   from private.web_preorder_events e
   join public.web_preorder_requests w on w.id=e.preorder_id
   where e.audience='customer' and w.install_id=v_id
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
  order by created_at desc,id desc limit p_limit
 ) v;
 return v_rows;
end;
$$;
revoke all on function public.customer_preorder_activity_list(text,text,text,integer)
 from public,anon,authenticated;
grant execute on function public.customer_preorder_activity_list(text,text,text,integer) to service_role;
