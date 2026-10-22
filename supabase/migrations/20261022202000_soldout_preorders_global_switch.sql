-- Sold-out preorders remain separate from manually curated/new-release preorders.
-- Closed by default. No inventory, historic price or existing order is modified.
insert into public.app_remote_config(key, value, description)
values ('features.soldout_preorders_enabled', 'false'::jsonb,
        'Admin-controlled global permission for advance orders on sold-out titles.')
on conflict (key) do nothing;

-- An admin-only toggle; read and write both require the existing verified admin secret.
create or replace function public.admin_soldout_preorder_manage(
  p_secret text, p_enabled boolean default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare current_enabled boolean;
        eligible integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Ruxsat yo‘q';
  end if;
  if p_enabled is not null then
    insert into public.app_remote_config (key, value, description, updated_at)
    values ('features.soldout_preorders_enabled', to_jsonb(p_enabled),
       'Admin-controlled global permission for advance orders on sold-out titles.', now())
    on conflict (key) do update
      set value = excluded.value, updated_at = now();
  end if;
  select coalesce(value = 'true'::jsonb, false)
    into current_enabled
  from public.app_remote_config where key = 'features.soldout_preorders_enabled';
  select count(*) into eligible
  from public.books b
  where b.is_active and b.stock = 0 and b.price > 0 and not b.preorder_enabled;
  return jsonb_build_object(
    'enabled', coalesce(current_enabled, false),
    'eligible_count', eligible
  );
end;
$$;
revoke all on function public.admin_soldout_preorder_manage(text,boolean) from public;
grant execute on function public.admin_soldout_preorder_manage(text,boolean)
to anon, authenticated, service_role;

-- The existing book-specific web preorder checkout reads this server-side.
-- The same toggle is verified again when submitting: cached client UI cannot bypass it.
create or replace function public.web_preorder_book_config(p_book_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'book_id', b.id,
    'book_title', b.title,
    'book_image_url', coalesce(nullif(b.thumbnail_url,''), b.image_url, ''),
    'enabled', b.is_active and (
      b.preorder_enabled
      or (b.stock = 0 and b.price > 0
          and coalesce((select v.value = 'true'::jsonb
                        from public.app_remote_config v
                        where v.key = 'features.soldout_preorders_enabled'), false))
    ),
    'arrival_note', case
      when b.preorder_enabled then coalesce(b.preorder_arrival_note,'')
      when b.stock = 0 then 'Qayta kelishi kutilmoqda (sana hozircha belgilanmagan)'
      else ''
    end,
    'deposit_amount', greatest(5000, b.preorder_deposit_min),
    'deposit_max', greatest(5000, b.preorder_deposit_min, b.preorder_deposit_max),
    'terms_token', md5(jsonb_build_array(
      b.id, b.title, b.image_url, b.thumbnail_url, b.is_active, b.stock,
      b.price, b.preorder_enabled, b.preorder_arrival_note,
      b.preorder_deposit_min, b.preorder_deposit_max,
      (select v.value from public.app_remote_config v
       where v.key = 'features.soldout_preorders_enabled')
    )::text),
    'revision', 1,
    'batch_quantity', 0
  )
  from public.books b
  where b.id = p_book_id and b.is_active;
$$;
revoke all on function public.web_preorder_book_config(uuid) from public, anon, authenticated;
grant execute on function public.web_preorder_book_config(uuid) to service_role;
