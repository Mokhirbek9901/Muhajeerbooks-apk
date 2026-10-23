-- Critical correctness: mark a preorder cancelled before restoring its
-- reserved copies, so the BEFORE-stock allocation trigger cannot reclaim
-- them for the now-cancelled order. Both writes remain one transaction.
CREATE OR REPLACE FUNCTION public.admin_native_preorder_set_status(p_secret text, p_id bigint, p_expected_status text, p_status text, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.preorders%rowtype; n text:=trim(coalesce(p_note,''));
        h private.preorder_stock_holds%rowtype; e record;
begin
  if public._admin_secret_ok(p_secret) is not true then raise exception 'Admin ruxsati yo‘q'; end if;
  if p_status not in ('waiting','accepted','cancelled') or p_id is null or length(n)>500 then
    raise exception 'Noto‘g‘ri holat yoki izoh'; end if;
  select * into v from public.preorders where id=p_id for update;
  if not found then raise exception 'Zakaz topilmadi'; end if;
  if exists(select 1 from private.admin_preorder_hidden a where a.source='native' and a.order_id=p_id::text)
    then raise exception 'Arxiv zakazi'; end if;
  if v.status is distinct from p_expected_status then raise exception 'Zakaz holati boshqa oynada o‘zgargan'; end if;
  if v.status=p_status then return jsonb_build_object('status',p_status,'duplicate',true); end if;
  if not ((v.status='waiting' and p_status in ('accepted','cancelled')) or
    (v.status='contacted' and p_status in ('accepted','cancelled')) or
    (v.status='accepted' and p_status='cancelled') or
    (v.status='arrived' and p_status='cancelled') or
    (v.status='cancelled' and p_status='waiting')) then raise exception 'Holat o‘tishi noto‘g‘ri'; end if;
  if p_status in ('cancelled','waiting') and length(n)<3 then raise exception 'Sababini yozing'; end if;
  if p_status='cancelled' then
    if exists(select 1 from private.preorder_payment_requests r where r.preorder_id=p_id and r.payment_state='verified')
      then raise exception 'Tasdiqlangan to‘lovni bekor qilishdan oldin qayta hisoblang'; end if;
    -- Change status BEFORE restoring available stock. Otherwise the stock
    -- trigger would immediately re-reserve these copies for this same order.
    update public.preorders set status='cancelled' where id=p_id;
    for e in select book_id,quantity from private.preorder_extra_holds
      where preorder_id=p_id order by book_id for update
    loop
      delete from private.preorder_extra_holds where preorder_id=p_id and book_id=e.book_id;
      update public.books set stock=stock+e.quantity where id=e.book_id;
    end loop;
    select * into h from private.preorder_stock_holds where preorder_id=p_id for update;
    if found then
      delete from private.preorder_stock_holds where preorder_id=p_id;
      update public.books set stock=stock+h.quantity where id=h.book_id;
    end if;
    update private.preorder_payment_requests set payment_state='cancelled',updated_at=now()
      where preorder_id=p_id;
  end if;
  if p_status<>'cancelled' then
    update public.preorders set status=p_status where id=p_id;
  end if;
  if p_status='accepted' then
    update public.books set stock=stock where id=v.book_id;
  end if;
  insert into private.admin_preorder_status_events(preorder_id,old_status,new_status,admin_note)
    values(p_id,v.status,p_status,n);
  return jsonb_build_object('status',p_status,'duplicate',false);
end;
$function$;
