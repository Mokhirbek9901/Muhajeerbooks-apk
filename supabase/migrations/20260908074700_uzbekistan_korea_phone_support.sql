create or replace function public._customer_phone_key(p_phone text)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  digits text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if digits like '00%' then
    digits := substring(digits from 3);
  end if;

  -- Uzbekistan mobile: +998 XX XXX XX XX or local 9 digits.
  if length(digits) = 12 and digits like '998%' then
    return digits;
  elsif length(digits) = 9 and digits !~ '^0' then
    return '998' || digits;
  end if;

  -- Korea mobile: 010-XXXX-XXXX or +82 10-XXXX-XXXX.
  if length(digits) = 11 and digits like '010%' then
    return '82' || substring(digits from 2);
  elsif length(digits) = 12 and digits like '8210%' then
    return digits;
  end if;

  return '';
end;
$$;
revoke all on function public._customer_phone_key(text) from public, anon, authenticated;

create or replace function public.customer_register_free(p_name text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
  clean_phone text := trim(coalesce(p_phone, ''));
  key_value text;
begin
  if length(clean_name) < 2 or length(clean_name) > 80 then
    raise exception 'Ismni to‘liq kiriting';
  end if;

  key_value := public._customer_phone_key(clean_phone);
  if key_value = '' then
    raise exception 'Faqat O‘zbekiston yoki Koreya mobil raqamini kiriting';
  end if;

  insert into public.customer_contacts(
    phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
  ) values (
    key_value, clean_name, clean_phone, now(), now(), 1
  )
  on conflict(phone_key) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    last_seen_at = now(),
    visit_count = public.customer_contacts.visit_count + 1;

  return jsonb_build_object('ok', true, 'phone_key', key_value);
end;
$$;
revoke all on function public.customer_register_free(text, text) from public;
grant execute on function public.customer_register_free(text, text) to anon, authenticated;

create or replace function public.sync_customer_contact_from_order()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := regexp_replace(trim(coalesce(new.customer_name, '')), '\s+', ' ', 'g');
  clean_phone text := trim(coalesce(new.phone, ''));
  key_value text;
begin
  if length(clean_name) < 2 then
    return new;
  end if;

  key_value := public._customer_phone_key(clean_phone);
  if key_value = '' then
    return new;
  end if;

  insert into public.customer_contacts(
    phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
  ) values (
    key_value, clean_name, clean_phone, new.created_at, new.created_at, 1
  )
  on conflict(phone_key) do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    first_seen_at = least(public.customer_contacts.first_seen_at, excluded.first_seen_at),
    last_seen_at = greatest(public.customer_contacts.last_seen_at, excluded.last_seen_at);

  return new;
end;
$$;
revoke all on function public.sync_customer_contact_from_order() from public, anon, authenticated;

-- Re-key any previously saved Uzbekistan local numbers without losing history.
insert into public.customer_contacts(
  phone_key, full_name, phone, first_seen_at, last_seen_at, visit_count
)
select
  public._customer_phone_key(phone),
  full_name,
  phone,
  first_seen_at,
  last_seen_at,
  visit_count
from public.customer_contacts
where public._customer_phone_key(phone) <> ''
  and public._customer_phone_key(phone) <> phone_key
on conflict(phone_key) do update set
  full_name = excluded.full_name,
  phone = excluded.phone,
  first_seen_at = least(public.customer_contacts.first_seen_at, excluded.first_seen_at),
  last_seen_at = greatest(public.customer_contacts.last_seen_at, excluded.last_seen_at),
  visit_count = greatest(public.customer_contacts.visit_count, excluded.visit_count);

delete from public.customer_contacts
where public._customer_phone_key(phone) <> ''
  and public._customer_phone_key(phone) <> phone_key;
