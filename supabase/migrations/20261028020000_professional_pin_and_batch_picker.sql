-- Keep Professional checkout separate from the full admin password.
-- Its four-digit access code remains hashed and checked on the server.
create or replace function public.customer_release_professional_login(p_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_token uuid;
begin
  if not coalesce(public.customer_professional_code_verify(p_code),false) then
    raise exception 'Professional kod noto‘g‘ri';
  end if;
  insert into private.release_professional_sessions default values
    returning token into v_token;
  return v_token;
end $$;
revoke all on function public.customer_release_professional_login(text)
  from public,anon,authenticated;
grant execute on function public.customer_release_professional_login(text)
  to service_role;

-- Read authoritative existing books for ONE selected batch at picker-open time.
-- The caller must pass the same protected admin secret used by all batch tools.
create or replace function public.admin_web_batch_existing_books(
 p_secret text,p_kind text,p_key text
) returns jsonb language plpgsql security definer set search_path='' as $func$
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_kind='group' then
    if p_key is null or p_key !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception 'Partiya identifikatori noto‘g‘ri';
    end if;
    if not exists(select 1 from public.web_batch_groups g where g.id=p_key::uuid) then
      raise exception 'Partiya topilmadi';
    end if;
    return coalesce((
      select jsonb_agg(jsonb_build_object('book_id',l.book_id,'title',b.title))
        from public.web_book_batches l join public.books b on b.id=l.book_id
        where l.batch_group_id=p_key::uuid
    ),'[]'::jsonb);
  elsif p_kind='import' then
    if p_key is null or p_key !~ '^[0-9]{1,18}$' then
      raise exception 'Partiya identifikatori noto‘g‘ri';
    end if;
    if not exists(select 1 from public.web_batch_imports i where i.id=p_key::bigint) then
      raise exception 'Partiya topilmadi';
    end if;
    return coalesce((
      select jsonb_agg(jsonb_build_object('book_id',l.book_id,'title',b.title))
        from public.web_book_batches l join public.books b on b.id=l.book_id
        where l.batch_import_id=p_key::bigint
    ),'[]'::jsonb);
  elsif p_kind='legacy' then
    if p_key is null or p_key !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Tarixiy partiya sanasi noto‘g‘ri';
    end if;
    if not exists(select 1 from public.web_book_batches l
      where l.purchased_at=p_key::date and l.batch_import_id is null
        and l.batch_group_id is null) then
      raise exception 'Tarixiy partiya topilmadi';
    end if;
    return coalesce((
      select jsonb_agg(jsonb_build_object('book_id',l.book_id,'title',b.title))
      from public.web_book_batches l join public.books b on b.id=l.book_id
      where l.purchased_at=p_key::date and l.batch_import_id is null
        and l.batch_group_id is null
    ),'[]'::jsonb);
  else
    raise exception 'Partiya turi noto‘g‘ri';
  end if;
end $func$;
revoke all on function public.admin_web_batch_existing_books(text,text,text)
  from public,anon,authenticated;
grant execute on function public.admin_web_batch_existing_books(text,text,text)
  to anon,authenticated,service_role;
