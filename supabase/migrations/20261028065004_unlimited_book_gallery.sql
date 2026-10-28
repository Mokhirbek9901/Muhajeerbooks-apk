-- Preserve the current atomic/admin-authenticated writer; remove only image-count truncation.
CREATE OR REPLACE FUNCTION private.normalize_book_gallery_urls(p_urls jsonb)
RETURNS text[] LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
 select coalesce(array_agg(url order by first_position), '{}'::text[])
 from (
   select btrim(value) url, min(position) first_position
   from jsonb_array_elements_text(p_urls) with ordinality e(value, position)
   where btrim(value) <> ''
   group by btrim(value)
 ) normalized
$$;
REVOKE ALL ON FUNCTION private.normalize_book_gallery_urls(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.release_save_book_base(p_secret text, p_id uuid, p_data jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_discount integer; v_new_image text; v_new_thumbnail text; v_old_image text; v_old_thumbnail text; v_old_images text[]:='{}'; v_images text[]:='{}'; v_title text;
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
-- Old app builds silently kept only their first 20 photos; reject that loss.
 if p_id is not null and jsonb_typeof(p_data->'image_urls')='array'
    and not coalesce((p_data->>'gallery_unlimited')::boolean,false)
    and exists(select 1 from public.books where id=p_id
       and cardinality(image_urls)>20
       and jsonb_array_length(p_data->'image_urls')<cardinality(image_urls)) then
  raise exception 'Barcha rasmlarni saqlash uchun ilovani yangilang yoki webdan foydalaning.';
 end if;
 v_discount:=least(99,greatest(0,coalesce((p_data->>'discount_percent')::integer,0)));
 v_new_image:=coalesce(trim(p_data->>'image_url'),''); v_new_thumbnail:=coalesce(trim(p_data->>'thumbnail_url'),'');
 v_title:=coalesce(nullif(trim(p_data->>'title'),''),'Nomsiz kitob');
 if p_data?'image_urls' and jsonb_typeof(p_data->'image_urls')='array' then
  v_images:=private.normalize_book_gallery_urls(p_data->'image_urls');
  v_new_image:=coalesce(v_images[1],'');
 elsif v_new_image<>'' then v_images:=array[v_new_image]; end if;
 if p_id is null then
  if exists(select 1 from public.books b where public.normalize_book_title(b.title)=public.normalize_book_title(v_title)) then raise exception 'Bu nomdagi kitob allaqachon mavjud'; end if;
  insert into public.books(title,author,publisher,category,description,page_count,price,stock,discount_percent,image_url,thumbnail_url,image_urls,is_active,recommended,preorder_enabled,preorder_arrival_note,preorder_deposit_min,preorder_deposit_max,cover,old_price,cost_price,telegram_photo_id)
  values(v_title,coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),btrim(regexp_replace(coalesce(p_data->>'publisher',''),'\s+',' ','g')),
   coalesce(nullif(trim(p_data->>'category'),''),'Boshqalar'),coalesce(nullif(trim(p_data->>'description'),''),'Ma’lumot kiritilmagan.'),
   greatest(0,coalesce((p_data->>'page_count')::integer,0)),
   greatest(0,coalesce((p_data->>'price')::integer,0)),greatest(0,coalesce((p_data->>'stock')::integer,0)),v_discount,
   v_new_image,v_new_thumbnail,v_images,coalesce((p_data->>'is_active')::boolean,true),coalesce((p_data->>'recommended')::boolean,false),
   coalesce((p_data->>'preorder_enabled')::boolean,false),left(coalesce(trim(p_data->>'preorder_arrival_note'),''),160),
   greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)),
   greatest(greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)),coalesce((p_data->>'preorder_deposit_max')::integer,10000)),
   coalesce(nullif(trim(p_data->>'cover'),''),'Ko‘rsatilmagan'),greatest(0,coalesce((p_data->>'old_price')::integer,0)),
   greatest(0,coalesce((p_data->>'cost_price')::integer,0)),'') returning id into v_id;
 else
  select image_url,thumbnail_url,image_urls into v_old_image,v_old_thumbnail,v_old_images from public.books where id=p_id;
  if not(p_data?'image_urls') then
   if v_new_image=coalesce(v_old_image,'') then v_images:=coalesce(v_old_images,'{}');
   elsif v_new_image<>'' then v_images:=array[v_new_image]||coalesce(v_old_images[2:],'{}'); else v_images:=coalesce(v_old_images[2:],'{}'); end if;
  end if;
  v_new_image:=coalesce(v_images[1],'');
  if not(p_data?'thumbnail_url') then v_new_thumbnail:=coalesce(v_old_thumbnail,''); end if;
  if coalesce(v_old_image,'') is distinct from v_new_image and not(p_data?'thumbnail_url') then v_new_thumbnail:=''; end if;
  update public.books set title=v_title,author=coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),
   publisher=case when p_data?'publisher' then btrim(regexp_replace(coalesce(p_data->>'publisher',''),'\s+',' ','g')) else publisher end,
   category=coalesce(nullif(trim(p_data->>'category'),''),'Boshqalar'),description=coalesce(nullif(trim(p_data->>'description'),''),'Ma’lumot kiritilmagan.'),
   page_count=case when p_data?'page_count' then greatest(0,coalesce((p_data->>'page_count')::integer,0)) else page_count end,
   price=greatest(0,coalesce((p_data->>'price')::integer,price)),stock=greatest(0,coalesce((p_data->>'stock')::integer,stock)),
   discount_percent=v_discount,image_urls=v_images,image_url=v_new_image,thumbnail_url=v_new_thumbnail,
   telegram_photo_id=case when coalesce(v_old_image,'') is distinct from v_new_image then '' else telegram_photo_id end,
   is_active=coalesce((p_data->>'is_active')::boolean,is_active),recommended=coalesce((p_data->>'recommended')::boolean,recommended),
   preorder_enabled=coalesce((p_data->>'preorder_enabled')::boolean,preorder_enabled),
   preorder_arrival_note=case when p_data?'preorder_arrival_note' then left(coalesce(trim(p_data->>'preorder_arrival_note'),''),160) else preorder_arrival_note end,
   preorder_deposit_min=case when p_data?'preorder_deposit_min' then greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)) else preorder_deposit_min end,
   preorder_deposit_max=case when p_data?'preorder_deposit_max' then greatest(case when p_data?'preorder_deposit_min' then greatest(0,coalesce((p_data->>'preorder_deposit_min')::integer,5000)) else preorder_deposit_min end,coalesce((p_data->>'preorder_deposit_max')::integer,10000)) else preorder_deposit_max end,
   cover=coalesce(nullif(trim(p_data->>'cover'),''),cover),old_price=greatest(0,coalesce((p_data->>'old_price')::integer,old_price)),
   cost_price=greatest(0,coalesce((p_data->>'cost_price')::integer,cost_price))
  where id=p_id returning id into v_id;
  if v_id is null then raise exception 'Kitob topilmadi'; end if;
 end if; return v_id;
end $function$
;
REVOKE ALL ON FUNCTION private.release_save_book_base(text,uuid,jsonb) FROM PUBLIC, anon, authenticated;

