-- Repair admin book creation deduplication without changing prices, stock or permissions.
-- The former expression `admin_save_book.request_id` was parsed as a missing table reference.
CREATE OR REPLACE FUNCTION public.admin_save_book(p_secret text, p_id uuid, p_data jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.books%rowtype; saved uuid; v_request_id uuid; data jsonb:=p_data;
begin
 if not coalesce(public._admin_secret_ok(p_secret),false) then raise exception 'Ruxsat yo‘q'; end if;
 if p_id is null and p_data?'request_id' then
  v_request_id:=(p_data->>'request_id')::uuid;
  perform pg_advisory_xact_lock(hashtextextended('book-save:'||v_request_id::text,0));
  select book_id into saved from private.release_book_requests r where r.request_id=v_request_id;
  if saved is not null then return saved; end if;
 end if;
 if p_id is not null then
  select * into b from public.books where id=p_id for update;
  if not found then raise exception 'Kitob topilmadi'; end if;
  if data?'expected_stock' then
   if (data->>'expected_stock')::integer<>b.stock then raise exception 'Ombor o‘zgargan. Kitobni yangilab qayta saqlang'; end if;
  else data:=data-'stock'; end if;
 end if;
 saved:=private.release_save_book_base(p_secret,p_id,data);
 update public.books set planned=coalesce((data->>'planned')::boolean,planned),
  preorder_price_max=case when data?'preorder_price_max' then greatest(0,(data->>'preorder_price_max')::integer) else preorder_price_max end
  where id=saved;
 if v_request_id is not null then insert into private.release_book_requests(request_id,book_id) values(v_request_id,saved); end if;
 return saved;
end $function$
;
