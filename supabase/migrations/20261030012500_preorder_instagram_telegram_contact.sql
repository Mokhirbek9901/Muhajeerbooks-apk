
-- Preorder contact method is optional for older installed app versions.
-- The existing instagram_handle column remains the compatible username field.
alter table public.preorders
  add column if not exists contact_platform text not null default 'instagram';
alter table public.web_preorder_requests
  add column if not exists contact_platform text not null default 'instagram';

do $$
begin
  if not exists(select 1 from pg_constraint where conname='preorders_contact_platform_valid') then
    alter table public.preorders add constraint preorders_contact_platform_valid
      check (contact_platform in ('instagram','telegram'));
  end if;
  if not exists(select 1 from pg_constraint where conname='web_preorder_contact_platform_valid') then
    alter table public.web_preorder_requests add constraint web_preorder_contact_platform_valid
      check (contact_platform in ('instagram','telegram'));
  end if;
end $$;

-- Modify only the small contact validation/persistence pieces of the
-- existing SECURITY DEFINER device dispatcher. All security and payment
-- checks remain unchanged, with a contract guard against unexpected source.
do $$
declare
  definition text := pg_get_functiondef('public.customer_device_dispatch(text,text,jsonb)'::regprocedure);
  old_validation text := $old$  if instagram !~ '^[A-Za-z0-9._]{1,30}$' then raise exception 'Instagram username kiriting: @username'; end if;
  p:=p-'p_instagram_handle';$old$;
  new_validation text := $new$  v_contact_platform:=lower(trim(coalesce(
     case when p_action='customer_preorder_submit'
          then p->>'p_contact_platform'
          else p->'p_request'->>'contact_platform' end,'instagram')));
  if v_contact_platform not in ('instagram','telegram') then
    raise exception 'Instagram yoki Telegram tanlang';
  end if;
  if (v_contact_platform='instagram' and instagram !~ '^[A-Za-z0-9._]{1,30}$') or
     (v_contact_platform='telegram' and instagram !~ '^[A-Za-z0-9_]{5,32}$') then
    raise exception 'Tanlangan tarmoqning username manzilini tekshiring: @username';
  end if;
  p:=p-'p_instagram_handle'-'p_contact_platform';$new$;
begin
  if definition is null
     or strpos(definition,'compat_install text; instagram text;')=0
     or strpos(definition,old_validation)=0
     or strpos(definition,'update public.preorders set instagram_handle=instagram where id=')=0
     or strpos(definition,'update public.web_preorder_requests set instagram_handle=instagram where id=')=0 then
    raise exception 'Device dispatcher source changed; cannot patch safely.';
  end if;
  definition:=replace(definition,
     'compat_install text; instagram text;',
     'compat_install text; instagram text; v_contact_platform text := ''instagram'';');
  definition:=replace(definition,old_validation,new_validation);
  definition:=replace(definition,
     'update public.preorders set instagram_handle=instagram where id=',
     'update public.preorders set instagram_handle=instagram,contact_platform=v_contact_platform where id=');
  definition:=replace(definition,
     'update public.web_preorder_requests set instagram_handle=instagram where id=',
     'update public.web_preorder_requests set instagram_handle=instagram,contact_platform=v_contact_platform where id=');
  execute definition;
end $$;

-- Admin native list must include the contact method and username.
do $$
declare
  definition text:=pg_get_functiondef('public.admin_preorders_all_list(text,integer,integer)'::regprocedure);
begin
  if definition is null or strpos(definition,
      'p.payment_proof_path,p.note,coalesce(b.preorder_arrival_note')=0 then
     raise exception 'Admin native preorder list shape changed; cannot patch safely.';
  end if;
  definition:=replace(definition,
      'p.payment_proof_path,p.note,coalesce(b.preorder_arrival_note',
      'p.payment_proof_path,p.note,p.instagram_handle,p.contact_platform,coalesce(b.preorder_arrival_note');
  execute definition;
end $$;
