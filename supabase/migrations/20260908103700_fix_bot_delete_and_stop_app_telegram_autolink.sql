drop trigger if exists orders_link_telegram_customer on public.orders;

update public.orders
set telegram_chat_id = null,
    telegram_username = ''
where source = 'app'
  and (telegram_chat_id is not null or coalesce(telegram_username, '') <> '');

create or replace function public.bot_sync_delete(
  p_secret text,
  p_telegram_id bigint default null,
  p_cloud_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_count integer := 0;
  v_tid bigint;
  v_cid uuid;
begin
  perform public.bot_sync_pull(p_secret);

  -- Avval cloud id bilan topamiz. Stale cloud_id bo‘lsa Telegram id orqali fallback qilamiz.
  if p_cloud_id is not null then
    select id, telegram_id into v_cid, v_tid
    from public.books
    where id = p_cloud_id;
  end if;

  if v_cid is null and p_telegram_id is not null and p_telegram_id > 0 then
    select id, telegram_id into v_cid, v_tid
    from public.books
    where telegram_id = p_telegram_id;
  end if;

  v_tid := coalesce(v_tid, p_telegram_id);

  if v_tid is not null and v_tid > 0 then
    insert into public.book_sync_tombstones(telegram_id, cloud_id, deleted_at)
    values(v_tid, v_cid, now())
    on conflict(telegram_id) do update
      set cloud_id = coalesce(excluded.cloud_id, public.book_sync_tombstones.cloud_id),
          deleted_at = now();
  end if;

  if v_cid is not null then
    delete from public.books where id = v_cid;
    get diagnostics v_count = row_count;
  end if;

  -- Cloud id noto‘g‘ri yoki eskirgan bo‘lsa ham Telegram id orqali haqiqiy qatorni o‘chiramiz.
  if v_count = 0 and v_tid is not null and v_tid > 0 then
    delete from public.books where telegram_id = v_tid;
    get diagnostics v_count = row_count;
  end if;

  return v_count;
end;
$function$;
