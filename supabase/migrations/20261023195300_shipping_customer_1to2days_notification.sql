-- Shipment is final for the shop; no new 'delivered' button or state.
-- Only the wording of the existing one-time customer notification changes.
-- Keep inventory, status transitions, idempotency and existing grants unchanged.
CREATE OR REPLACE FUNCTION public._order_set_status_core(p_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.orders%rowtype; item jsonb; bid uuid; qty integer; b public.books%rowtype;
 needs_reserve boolean; changed boolean; display_no bigint;
begin
 if p_status not in ('new','accepted','paid','shipping','cancelled') then raise exception 'Noto‘g‘ri holat'; end if;
 select * into o from public.orders where id=p_id for update;
 if not found then raise exception 'Buyurtma topilmadi'; end if;
 if o.status='cancelled' and p_status<>'cancelled' then raise exception 'Bekor qilingan buyurtmani qayta faollashtirib bo‘lmaydi'; end if;
 if o.status='shipping' and p_status<>'shipping' then raise exception 'Jo‘natilgan buyurtma yakuniy holatda'; end if;
 changed:=o.status is distinct from p_status; display_no:=coalesce(o.display_order_number,o.order_number);
 needs_reserve:=p_status in ('new','accepted','paid','shipping') and not o.stock_reserved;
 if needs_reserve then
  for item in select * from jsonb_array_elements(o.items) loop
   bid:=(item->>'book_id')::uuid; qty:=greatest(coalesce((item->>'quantity')::integer,0),0);
   if qty<=0 then raise exception 'Buyurtma tarkibi noto‘g‘ri'; end if;
   select * into b from public.books where id=bid for update;
   if not found then raise exception 'Buyurtmadagi kitob topilmadi'; end if;
   if b.stock<qty then raise exception '“%” uchun omborda % dona kerak, % dona bor',b.title,qty,b.stock; end if;
  end loop;
  for item in select * from jsonb_array_elements(o.items) loop
   bid:=(item->>'book_id')::uuid; qty:=(item->>'quantity')::integer; update public.books set stock=stock-qty where id=bid;
  end loop;
  update public.orders set status=p_status,stock_reserved=true,stock_restored=false where id=p_id;
 elsif p_status='cancelled' and o.status<>'cancelled' then
  if o.stock_reserved and not o.stock_restored then
   for item in select * from jsonb_array_elements(o.items) loop
    bid:=(item->>'book_id')::uuid; qty:=greatest(coalesce((item->>'quantity')::integer,0),0); update public.books set stock=stock+qty where id=bid;
   end loop;
  end if;
  update public.orders set status='cancelled',stock_reserved=false,stock_restored=(o.stock_reserved or o.stock_restored) where id=p_id;
 else update public.orders set status=p_status where id=p_id;
 end if;
 if changed and p_status in ('accepted','shipping') and trim(coalesce(o.phone,''))<>'' then
  insert into public.customer_push_messages(phone,title,body,kind,order_number,order_id,sent_at)
  values(o.phone,
   case when p_status='accepted' then 'Buyurtma qabul qilindi ✅' else 'Buyurtmangiz yuborildi 🚚' end,
   case when p_status='accepted' then 'Muhajeer Books • #'||display_no||' buyurtmangiz qabul qilindi.'
        else 'Buyurtmangiz jo‘natildi! Pochta orqali odatda 1–2 kunda yetib boradi. Kuzatuv raqami berilgan bo‘lsa, uni “Mening buyurtmalarim” sahifasida ko‘rishingiz mumkin.' end,
   'order_status',display_no,o.id,now());
 end if;
end;
$function$

