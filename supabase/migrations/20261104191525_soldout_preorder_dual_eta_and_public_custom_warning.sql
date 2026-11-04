ALTER TABLE private.soldout_preorder_bulk_selections ADD COLUMN IF NOT EXISTS arrival_end_date date;
ALTER TABLE private.soldout_preorder_bulk_selections DROP CONSTRAINT IF EXISTS soldout_preorder_bulk_arrival_range_valid;
ALTER TABLE private.soldout_preorder_bulk_selections ADD CONSTRAINT soldout_preorder_bulk_arrival_range_valid CHECK (arrival_end_date IS NULL OR arrival_end_date >= arrival_date);
ALTER TABLE public.web_preorder_settings ADD COLUMN IF NOT EXISTS customer_notice text NOT NULL DEFAULT '';
ALTER TABLE public.web_preorder_settings DROP CONSTRAINT IF EXISTS web_preorder_customer_notice_length;
ALTER TABLE public.web_preorder_settings ADD CONSTRAINT web_preorder_customer_notice_length CHECK (char_length(customer_notice) <= 600);
CREATE OR REPLACE FUNCTION public.admin_soldout_preorder_bulk(p_secret text, p_mode text DEFAULT 'list'::text, p_rows jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '12s'
AS $function$
declare
  entry jsonb;
  v_id uuid;
  v_date date;
  v_end date;
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
          'end_date',coalesce(m.arrival_end_date,m.arrival_date),
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
        v_end:=coalesce((entry->>'end_date')::date,v_date);
        v_deposit:=(entry->>'deposit')::integer;
      exception when others then
        raise exception 'Kitob, sana yoki avans noto‘g‘ri kiritilgan';
      end;
      if v_id is null or v_date is null or v_end is null or v_deposit is null or
         v_end < v_date or v_end > v_date + 730 or
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
      v_end:=coalesce((entry->>'end_date')::date,v_date);
      v_deposit:=(entry->>'deposit')::integer;
      update public.books set
        preorder_enabled=true,
        preorder_arrival_note=to_char(v_date,'YYYY-MM-DD') || ' ~ ' || to_char(v_end,'YYYY-MM-DD'),
        preorder_deposit_min=v_deposit,
        preorder_deposit_max=v_deposit,
        updated_at=now()
      where id=v_id;
      insert into private.soldout_preorder_bulk_selections(book_id,arrival_date,arrival_end_date,deposit_won)
      values(v_id,v_date,v_end,v_deposit)
      on conflict(book_id) do update
      set arrival_date=excluded.arrival_date,
          arrival_end_date=excluded.arrival_end_date,
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
$function$;
CREATE OR REPLACE FUNCTION public.admin_web_preorder_manage(p_secret text, p_action text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.web_preorder_settings%rowtype; r public.web_preorder_requests%rowtype;
 enabled_value boolean; arrival text; amount integer; batch integer; target text; note_value text;
 range_provided boolean; start_date date; end_date date; notice_text text;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='settings' then return public.web_preorder_config();
 elsif p_action='save' then
  enabled_value:=(p_payload->>'enabled')::boolean; arrival:=trim(coalesce(p_payload->>'arrival_note',''));
  amount:=(p_payload->>'deposit_amount')::integer; batch:=(p_payload->>'batch_quantity')::integer;
  notice_text:=trim(coalesce(p_payload->>'customer_notice',''));
  IF p_payload ? 'customer_notice' AND char_length(notice_text)>600 THEN RAISE EXCEPTION 'Ogohlantirish izohi 600 belgidan oshmasin.'; END IF;
  -- New admin versions supply two exact dates. Existing mobile versions
  -- continue to read arrival_note, which now contains the display interval.
  -- Older admins saving legacy text preserve existing date columns.
  range_provided := p_payload ? 'arrival_start' OR p_payload ? 'arrival_end';
  IF range_provided THEN
    IF coalesce(jsonb_typeof(p_payload->'arrival_start'),'null') <> 'string'
       OR coalesce(jsonb_typeof(p_payload->'arrival_end'),'null') <> 'string' THEN
      RAISE EXCEPTION 'Boshlanish va tugash sanalarini tanlang.';
    END IF;
    start_date := (p_payload->>'arrival_start')::date;
    end_date := (p_payload->>'arrival_end')::date;
    IF start_date IS NULL OR end_date IS NULL OR end_date < start_date
       OR end_date > start_date + 730 THEN
      RAISE EXCEPTION 'Kelish sanalari oralig‘ini tekshiring.';
    END IF;
    arrival := to_char(start_date,'YYYY.MM.DD') || ' ~ ' ||
               to_char(end_date,'YYYY.MM.DD');
  END IF;
  if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
    (enabled_value and arrival='') or amount not between 5000 and 10000000 or batch not between 0 and 100000 then
   raise exception 'Sana, avans va sonni tekshiring.'; end if;
  select * into s from public.web_preorder_settings where id for update;
  if (p_payload->>'revision')::bigint is distinct from s.revision then
   raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.'; end if;
  update public.web_preorder_settings
  set enabled=enabled_value,arrival_note=arrival,deposit_amount=amount,
    batch_quantity=batch,revision=revision+1,updated_at=now(),
    arrival_start=case when range_provided then start_date else arrival_start end,
    arrival_end=case when range_provided then end_date else arrival_end end,
    customer_notice=case when p_payload ? 'customer_notice' then notice_text else customer_notice end
  where id;
  return public.web_preorder_config();
 elsif p_action='list' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select req.*,
    (select e.delivery_state from private.web_preorder_events e where e.preorder_id=req.id and e.audience='customer' order by version desc limit 1) as notification_state,
    (select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'created_at',h.created_at,'message',h.body) order by h.version desc),'[]') from private.web_preorder_events h where h.preorder_id=req.id and h.audience='customer') as history
    from public.web_preorder_requests req
    where not exists (select 1 from private.admin_preorder_hidden h
      where h.source='web' and h.order_id=req.id::text)
    order by req.created_at desc,req.id desc
      limit least(200,greatest(1,coalesce((p_payload->>'limit')::integer,200)))
      offset greatest(0,coalesce((p_payload->>'offset')::integer,0))) x),'[]');
 elsif p_action='status' then
  target:=p_payload->>'status'; note_value:=trim(coalesce(p_payload->>'note',''));
  if target is null or target not in ('waiting','accepted','arrived','cancelled') or length(note_value)>500 then raise exception 'Noto‘g‘ri holat'; end if;
  select * into r from public.web_preorder_requests q where q.id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Buyurtma topilmadi'; end if;
  if r.status=target then return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',true); end if;
  if (p_payload->>'version')::integer is distinct from r.status_version then raise exception 'Holat boshqa oynada o‘zgargan. Ro‘yxatni yangilang.'; end if;
  if not ((r.status='waiting' and target in ('accepted','cancelled')) or
    (r.status='accepted' and target in ('arrived','cancelled')) or
    (r.status='arrived' and target='cancelled') or
    (r.status='cancelled' and target='waiting')) then raise exception 'Avval buyurtmani qabul qiling yoki bekor qilingan buyurtmani qayta oching.'; end if;
  if r.status='cancelled' and target='waiting' and exists(
    select 1 from public.web_preorder_requests newer
     where newer.id<>r.id and newer.phone=r.phone
       and newer.status in ('waiting','accepted','arrived')
       and ( (r.book_id is not null and newer.book_id=r.book_id)
         or (r.book_id is null and newer.book_id is null and newer.book_title=r.book_title))
  ) then
    raise exception 'Bu mijoz allaqachon yangi faol zakaz yuborgan. Eski bekor qilinganini qayta ochmang.';
  end if;
  if target in ('cancelled','waiting') and length(note_value)<3 then raise exception 'Sababini yozing (kamida 3 belgi).'; end if;
  update public.web_preorder_requests q set status=target,status_note=note_value,status_version=q.status_version+1,updated_at=now() where q.id=r.id returning * into r;
  return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',false,'inbox_created',true);
 end if;
 raise exception 'Noto‘g‘ri amal';
end;
$function$;

