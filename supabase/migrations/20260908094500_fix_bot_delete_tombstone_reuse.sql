-- Keep the current catalog authoritative if an old tombstone belongs to a book
-- that was intentionally restored later.
delete from public.book_sync_tombstones t
using public.books b
where b.telegram_id = t.telegram_id
  and b.created_at > t.deleted_at;

create or replace function public.bot_sync_push_safe(p_secret text, p_books jsonb)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  b jsonb;
  tid bigint;
  cloud uuid;
  v_count integer := 0;
  v_bot_price integer;
  v_old integer;
  v_base_price integer;
  v_discount integer;
  v_deleted_at timestamptz;
  v_created_at timestamptz;
begin
  perform public.bot_sync_pull(p_secret);
  if jsonb_typeof(p_books) <> 'array' then
    raise exception 'Kitoblar array bo‘lishi kerak';
  end if;

  for b in select * from jsonb_array_elements(p_books)
  loop
    begin
      tid := (b->>'id')::bigint;
    exception when others then
      continue;
    end;
    if tid is null or tid <= 0 then continue; end if;

    -- Stale local copies must not resurrect a deleted book. If the same
    -- Telegram id is later reused for a genuinely new book, its created_at
    -- is newer than the tombstone and the id may be used again safely.
    v_deleted_at := null;
    select deleted_at into v_deleted_at
    from public.book_sync_tombstones
    where telegram_id = tid;

    if v_deleted_at is not null then
      if exists(select 1 from public.books where telegram_id = tid) then
        delete from public.book_sync_tombstones where telegram_id = tid;
      else
        begin
          v_created_at := nullif(b->>'created_at','')::timestamptz;
        exception when others then
          v_created_at := null;
        end;

        if v_created_at is not null and v_created_at > v_deleted_at then
          delete from public.book_sync_tombstones where telegram_id = tid;
        else
          continue;
        end if;
      end if;
    end if;

    v_bot_price := greatest(0, coalesce((b->>'price')::integer,0));
    v_old := greatest(0, coalesce((b->>'old_price')::integer,0));
    v_base_price := case when v_old>v_bot_price and v_old>0 then v_old else v_bot_price end;
    v_discount := least(99,greatest(0,coalesce((b->>'discount_percent')::integer,
      case when v_old>v_bot_price and v_old>0
        then round((v_old-v_bot_price)*100.0/v_old)::integer else 0 end)));
    if v_discount>0 and v_old<=v_bot_price then
      v_base_price := greatest(v_bot_price,round(v_bot_price*100.0/greatest(1,100-v_discount))::integer);
    end if;
    begin
      cloud := nullif(b->>'cloud_id','')::uuid;
    exception when others then
      cloud := null;
    end;

    if cloud is not null then
      if not exists(select 1 from public.books where id=cloud) then
        continue;
      end if;
      update public.books set
        telegram_id=tid,
        title=coalesce(nullif(trim(b->>'name'),''),'Nomsiz kitob'),
        author=coalesce(nullif(trim(b->>'author'),''),'Ko‘rsatilmagan'),
        category=coalesce(nullif(trim(b->>'category'),''),'Boshqalar'),
        description=coalesce(nullif(trim(b->>'description'),''),'Ma’lumot kiritilmagan.'),
        price=v_base_price,
        old_price=v_old,
        cost_price=greatest(0,coalesce((b->>'cost_price')::integer,0)),
        stock=greatest(0,coalesce((b->>'stock')::integer,0)),
        discount_percent=v_discount,
        image_url=coalesce(b->>'image_url',''),
        telegram_photo_id=coalesce(b->>'photo_id',''),
        cover=coalesce(nullif(trim(b->>'cover'),''),'Ko‘rsatilmagan'),
        recommended=coalesce((b->>'recommended')::boolean,false),
        is_active=coalesce((b->>'is_active')::boolean,true)
      where id=cloud;
    else
      insert into public.books(
        telegram_id,title,author,category,description,price,old_price,cost_price,
        stock,discount_percent,image_url,telegram_photo_id,cover,recommended,is_active
      ) values(
        tid,
        coalesce(nullif(trim(b->>'name'),''),'Nomsiz kitob'),
        coalesce(nullif(trim(b->>'author'),''),'Ko‘rsatilmagan'),
        coalesce(nullif(trim(b->>'category'),''),'Boshqalar'),
        coalesce(nullif(trim(b->>'description'),''),'Ma’lumot kiritilmagan.'),
        v_base_price,v_old,
        greatest(0,coalesce((b->>'cost_price')::integer,0)),
        greatest(0,coalesce((b->>'stock')::integer,0)),
        v_discount,
        coalesce(b->>'image_url',''),
        coalesce(b->>'photo_id',''),
        coalesce(nullif(trim(b->>'cover'),''),'Ko‘rsatilmagan'),
        coalesce((b->>'recommended')::boolean,false),
        coalesce((b->>'is_active')::boolean,true)
      )
      on conflict(telegram_id) do update set
        title=excluded.title,
        author=excluded.author,
        category=excluded.category,
        description=excluded.description,
        price=excluded.price,
        old_price=excluded.old_price,
        cost_price=excluded.cost_price,
        stock=excluded.stock,
        discount_percent=excluded.discount_percent,
        image_url=excluded.image_url,
        telegram_photo_id=excluded.telegram_photo_id,
        cover=excluded.cover,
        recommended=excluded.recommended,
        is_active=excluded.is_active;
    end if;
    v_count := v_count+1;
  end loop;
  return v_count;
end;
$function$;
