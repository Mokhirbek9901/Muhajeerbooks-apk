
-- Individually selected sold-out preorders. Records only the books enabled by this admin tool.
-- Existing manual preorders and received deposits/orders are not modified.
create table if not exists private.soldout_preorder_bulk_selections (
  book_id uuid primary key references public.books(id) on delete cascade,
  arrival_date date not null,
  deposit_won integer not null check (deposit_won between 1000 and 1000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on private.soldout_preorder_bulk_selections from public, anon, authenticated;

create or replace function public.admin_soldout_preorder_bulk(
  p_secret text,
  p_mode text default 'list',
  p_rows jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = '' set statement_timeout = '12s'
as $fn$
declare
  entry jsonb;
  v_id uuid;
  v_date date;
  v_deposit integer;
  v_book public.books%rowtype;
  allowed uuid[] := '{}'::uuid[];
  total integer := 0;
  global_enabled boolean := false;
begin
  if not coalesce(public._admin_secret_ok(p_secret), false) then
    raise exception 'Ruxsat yo‘q';
  end if;
  if p_mode not in ('list','apply','clear') then
    raise exception 'Amal noto‘g‘ri';
  end if;
  if p_mode='list' then
    select coalesce(value = 'true'::jsonb,false) into global_enabled
    from public.app_remote_config where key='features.soldout_preorders_enabled';
    return jsonb_build_object(
      'global_enabled',coalesce(global_enabled,false),
      'managed',coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',m.book_id,
          'date',m.arrival_date,
          'deposit',m.deposit_won
        ) order by b.title)
        from private.soldout_preorder_bulk_selections m
        join public.books b on b.id=m.book_id
        where b.is_active and b.stock=0
      ),'[]'::jsonb)
    );
  end if;
  perform pg_advisory_xact_lock(hashtextextended('admin_soldout_preorder_bulk',0));

  if p_mode='apply' then
    if jsonb_typeof(p_rows) is distinct from 'array'
      or jsonb_array_length(p_rows)>500 then
      raise exception 'Kitoblar ro‘yxati noto‘g‘ri';
    end if;
    for entry in select value from jsonb_array_elements(p_rows) loop
      begin
        v_id:=(entry->>'id')::uuid;
        v_date:=(entry->>'date')::date;
        v_deposit:=(entry->>'deposit')::integer;
      exception when others then
        raise exception 'Kitob, sana yoki avans noto‘g‘ri kiritilgan';
      end;
      if v_id is null or v_date is null or v_deposit is null or
         v_date < (now() at time zone 'Asia/Seoul')::date or
         v_deposit < 1000 or v_deposit > 1000000 then
        raise exception 'Kelish sanasi va avansni tekshiring';
      end if;
      if v_id=any(allowed) then raise exception 'Bir kitob takrorlangan'; end if;
      select * into v_book from public.books where id=v_id for update;
      if not found or not v_book.is_active or v_book.stock<>0 or v_book.price<=0 then
        raise exception 'Faqat omborda tugagan, faol kitobni tanlang';
      end if;
      if v_book.preorder_enabled and
        not exists(select 1 from private.soldout_preorder_bulk_selections where book_id=v_id) then
        raise exception 'Kitob allaqachon boshqa oldindan sotuvda: %',v_book.title;
      end if;
      allowed:=array_append(allowed,v_id);
    end loop;

    -- Only remove marks that this screen originally created; other preorder titles stay untouched.
    update public.books b set preorder_enabled=false, updated_at=now()
    where b.id in (
      select m.book_id from private.soldout_preorder_bulk_selections m
      where not(m.book_id=any(allowed))
    );
    delete from private.soldout_preorder_bulk_selections m
    where not(m.book_id=any(allowed));

    for entry in select value from jsonb_array_elements(p_rows) loop
      v_id:=(entry->>'id')::uuid;
      v_date:=(entry->>'date')::date;
      v_deposit:=(entry->>'deposit')::integer;
      update public.books set
        preorder_enabled=true,
        preorder_arrival_note=to_char(v_date,'YYYY-MM-DD'),
        preorder_deposit_min=v_deposit,
        preorder_deposit_max=v_deposit,
        updated_at=now()
      where id=v_id;
      insert into private.soldout_preorder_bulk_selections(book_id,arrival_date,deposit_won)
      values(v_id,v_date,v_deposit)
      on conflict(book_id) do update
      set arrival_date=excluded.arrival_date,
          deposit_won=excluded.deposit_won,
          updated_at=now();
    end loop;
  else
    update public.books b set preorder_enabled=false, updated_at=now()
    from private.soldout_preorder_bulk_selections m where b.id=m.book_id;
    delete from private.soldout_preorder_bulk_selections;
  end if;

  -- A global sold-out switch would expose books the admin did not select.
  -- Selection mode is authoritative; normal/special preorder flags are untouched.
  insert into public.app_remote_config(key,value,description,updated_at)
  values ('features.soldout_preorders_enabled','false'::jsonb,
       'Use individual sold-out preorder selections', now())
  on conflict(key) do update set value='false'::jsonb,updated_at=now();

  select count(*) into total from private.soldout_preorder_bulk_selections;
  return jsonb_build_object('saved',total,'mode',p_mode);
end;
$fn$;
revoke all on function public.admin_soldout_preorder_bulk(text,text,jsonb)
from public, anon, authenticated;
grant execute on function public.admin_soldout_preorder_bulk(text,text,jsonb) to service_role;
