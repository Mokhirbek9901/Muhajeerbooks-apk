-- Advance is per copy, so two copies require twice the per-book deposit.
CREATE OR REPLACE FUNCTION public.customer_preorder_submit(p_install_id text, p_book_id uuid, p_customer_name text DEFAULT ''::text, p_phone text DEFAULT ''::text, p_quantity integer DEFAULT 1, p_deposit_amount integer DEFAULT 0, p_payment_proof_path text DEFAULT ''::text, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.preorders; v_min integer; v_max integer;
begin
  if length(trim(p_install_id))<12 or p_quantity is null or p_quantity<1 or p_quantity>20 then raise exception 'Invalid preorder'; end if;
  select preorder_deposit_min,preorder_deposit_max into v_min,v_max
  from public.books where id=p_book_id and is_active=true and preorder_enabled=true;
  if not found then raise exception 'Oldindan sotuv yopiq'; end if;
  if p_deposit_amount is null or p_deposit_amount < v_min*p_quantity or p_deposit_amount > v_max*p_quantity then
    raise exception 'Jami avans %–% won bo‘lishi kerak',v_min*p_quantity,v_max*p_quantity;
  end if;
  if trim(coalesce(p_payment_proof_path,''))='' then raise exception 'To‘lov cheki kerak'; end if;
  insert into public.preorders(book_id,install_id,customer_name,phone,quantity,status,deposit_amount,payment_proof_path,note)
  values(p_book_id,trim(p_install_id),left(trim(p_customer_name),80),left(trim(p_phone),32),p_quantity,'waiting',
         p_deposit_amount,left(trim(p_payment_proof_path),500),left(trim(p_note),500))
  on conflict (book_id,install_id) where status='waiting'
  do update set customer_name=excluded.customer_name,phone=excluded.phone,quantity=excluded.quantity,
                deposit_amount=excluded.deposit_amount,payment_proof_path=excluded.payment_proof_path,
                note=excluded.note,created_at=now()
  returning * into r;
  return jsonb_build_object('id',r.id,'status',r.status,'deposit_amount',r.deposit_amount);
end $function$;
