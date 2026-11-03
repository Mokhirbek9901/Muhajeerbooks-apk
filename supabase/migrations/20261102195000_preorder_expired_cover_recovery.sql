-- The underlying original book images are still in Storage. Remove only
-- expired temporary links mistakenly saved as admin display overrides.
-- Do not modify customer orders, titles, receipts or image objects.
delete from private.preorder_supplier_image_overrides o
where o.source='web'
  and o.image_url like '%/storage/v1/object/sign/web-preorder-assets/%'
  and exists (select 1 from public.web_preorder_requests w
              where w.id::text=o.order_id)
  and exists (select 1 from storage.objects s
              where s.bucket_id='web-preorder-assets'
              and s.name=(
                 select case when jsonb_typeof(w.request_items)='array'
                     and jsonb_array_length(w.request_items)>o.item_index
                   then w.request_items->o.item_index->>'book_image_path'
                   else w.book_image_path end
                 from public.web_preorder_requests w
                 where w.id::text=o.order_id
              ));

create or replace function public.admin_preorder_supplier(p_secret text,
  p_action text, p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $body$
declare v_id uuid;
        v_name text;
        v_lines jsonb;
        v_line jsonb;
        v_source text;
        v_order text;
        v_index integer;
        v_title text;
        v_url text;
        v_count integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
     raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_action='list' then
    return jsonb_build_object(
      'drafts',coalesce((select jsonb_agg(to_jsonb(d) order by d.updated_at desc)
        from (select * from private.preorder_supplier_drafts
              order by updated_at desc limit 100) d),'[]'::jsonb),
      'overrides',coalesce((select jsonb_agg(to_jsonb(t))
        from (select * from private.preorder_supplier_title_overrides
              order by updated_at desc limit 5000) t),'[]'::jsonb),
      'image_overrides',coalesce((select jsonb_agg(to_jsonb(t))
        from (select * from private.preorder_supplier_image_overrides
              order by updated_at desc limit 5000) t),'[]'::jsonb)
    );
  elsif p_action='save_draft' then
    v_name:=btrim(coalesce(p_payload->>'name',''));
    v_lines:=p_payload->'lines';
    if length(v_name) not between 1 and 160
       or jsonb_typeof(v_lines) is distinct from 'array'
       or jsonb_array_length(v_lines)>500 then
      raise exception 'Ro‘yxat nomi yoki kitoblar soni noto‘g‘ri';
    end if;
    for v_line in select value from jsonb_array_elements(v_lines) loop
      if jsonb_typeof(v_line) <> 'object'
       or length(btrim(coalesce(v_line->>'title',''))) not between 1 and 240
       or length(coalesce(v_line->>'publisher',''))>160
       or length(coalesce(v_line->>'image_url',''))>2200
       or length(coalesce(v_line->>'source_ref',''))>150
       or length(coalesce(v_line->>'item_key','')) not between 1 and 260
       or jsonb_typeof(v_line->'quantity') <> 'number'
       or jsonb_typeof(v_line->'requested') <> 'number'
       or (v_line->>'quantity')::integer not between 0 and 10000
       or (v_line->>'requested')::integer not between 0 and 10000 then
         raise exception 'Noto‘g‘ri kitob qatori: %, %',
           left(coalesce(v_line->>'title',''),40), v_line->>'quantity';
      end if;
    end loop;
    if nullif(p_payload->>'id','') is not null then
      v_id:=(p_payload->>'id')::uuid;
      update private.preorder_supplier_drafts set name=v_name,
        lines=v_lines,updated_at=now() where id=v_id;
      if not found then raise exception 'Saqlangan ro‘yxat topilmadi'; end if;
    else
      insert into private.preorder_supplier_drafts(name,lines)
      values(v_name,v_lines) returning id into v_id;
    end if;
    return jsonb_build_object('id',v_id,'saved',jsonb_array_length(v_lines));
  elsif p_action='delete_draft' then
    v_id:=(p_payload->>'id')::uuid;
    delete from private.preorder_supplier_drafts where id=v_id;
    if not found then raise exception 'Ro‘yxat topilmadi'; end if;
    return jsonb_build_object('deleted',true,'id',v_id);
  elsif p_action='set_title' then
    v_source:=coalesce(p_payload->>'source','');
    v_order:=coalesce(p_payload->>'order_id','');
    v_index:=coalesce((p_payload->>'item_index')::integer,0);
    v_title:=btrim(coalesce(p_payload->>'title',''));
    if v_source not in ('native','web') or v_index not between 0 and 499
       or length(v_title)>240 or length(v_order)>64 or v_order=''
    then raise exception 'Kitob ma’lumotlari noto‘g‘ri'; end if;
    if v_source='native' then
      if v_index<>0 or not exists
         (select 1 from public.preorders where id=v_order::bigint)
      then raise exception 'Oldindan buyurtma topilmadi'; end if;
    else
      if not exists (
        select 1 from public.web_preorder_requests w where w.id=v_order::uuid
        and v_index < greatest(
          1,case when jsonb_typeof(w.request_items)='array'
            then jsonb_array_length(w.request_items) else 0 end)
      ) then raise exception 'Bu kitob so‘rovi topilmadi'; end if;
    end if;
    if v_title='' then
      delete from private.preorder_supplier_title_overrides
      where source=v_source and order_id=v_order and item_index=v_index;
    else
      insert into private.preorder_supplier_title_overrides
       (source,order_id,item_index,display_title) values
       (v_source,v_order,v_index,v_title)
      on conflict(source,order_id,item_index) do update
       set display_title=excluded.display_title,updated_at=now();
    end if;
    return jsonb_build_object('saved',true,'source',v_source,
      'order_id',v_order,'item_index',v_index,'title',v_title);

  elsif p_action='set_book' then
    -- One transaction updates admin-only display metadata. Customer orders,
    -- quantities, deposits and inventory are never touched.
    v_source:=coalesce(p_payload->>'source','');
    v_order:=coalesce(p_payload->>'order_id','');
    v_index:=coalesce((p_payload->>'item_index')::integer,0);
    v_title:=btrim(coalesce(p_payload->>'title',''));
    v_url:=btrim(coalesce(p_payload->>'image_url',''));
    if v_source not in ('native','web') or v_index not between 0 and 499
       or length(v_title) not between 1 and 240
       or length(v_order) not between 1 and 64
       or length(v_url)>2200
       or (v_url<>'' and v_url not like 'https://%') then
      raise exception 'Tahrir ma’lumotlari noto‘g‘ri';
    end if;
    if v_source='native' then
      if v_index<>0 or not exists
        (select 1 from public.preorders where id=v_order::bigint)
      then raise exception 'Oldindan buyurtma topilmadi'; end if;
    else
      if not exists (
        select 1 from public.web_preorder_requests w where w.id=v_order::uuid
        and v_index < greatest(1,case
          when jsonb_typeof(w.request_items)='array'
            then jsonb_array_length(w.request_items) else 0 end)
      ) then raise exception 'Bu kitob so‘rovi topilmadi'; end if;
    end if;
    insert into private.preorder_supplier_title_overrides
      (source,order_id,item_index,display_title)
    values (v_source,v_order,v_index,v_title)
    on conflict(source,order_id,item_index) do update set
      display_title=excluded.display_title, updated_at=now();
    -- A web-preorder book_image_url is a 15-minute *signed* link. It is
    -- never a permanent cover override, even when saving the title. Legacy
    -- clients did send the current image_url on every title edit.
    if v_url like
       'https://rytfhjvhjxnbhgitowho.supabase.co/storage/v1/object/public/book-covers/covers/%'
    then
      if not exists (
        select 1 from storage.objects o where o.bucket_id='book-covers'
        and o.name=substring(v_url from length(
          'https://rytfhjvhjxnbhgitowho.supabase.co/storage/v1/object/public/book-covers/')+1)
      ) then raise exception 'Yangi kitob rasmi omborda topilmadi'; end if;
      insert into private.preorder_supplier_image_overrides
        (source,order_id,item_index,image_url)
      values(v_source,v_order,v_index,v_url)
      on conflict(source,order_id,item_index) do update
        set image_url=excluded.image_url,updated_at=now();
    elsif coalesce(p_payload->>'image_changed','false')='true' then
      if v_url='' then
        delete from private.preorder_supplier_image_overrides
          where source=v_source and order_id=v_order and item_index=v_index;
      else
        raise exception 'Faqat doimiy kitob rasmi saqlanishi mumkin';
      end if;
    end if;
    return jsonb_build_object('saved',true,'source',v_source,
       'order_id',v_order,'item_index',v_index);
  else
    raise exception 'Noma’lum amal';
  end if;
end;
$body$;
revoke all on function public.admin_preorder_supplier(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.admin_preorder_supplier(text,text,jsonb) to service_role;
