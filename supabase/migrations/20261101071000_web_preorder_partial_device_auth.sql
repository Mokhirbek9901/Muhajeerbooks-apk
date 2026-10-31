create or replace function public.customer_web_preorder_partial(
 p_session text,p_id uuid,p_action text default 'detail',p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.customer_device_profiles%rowtype;
 is_device boolean:=coalesce(p_session,'') like 'device:%';
 w public.web_preorder_requests%rowtype; b private.web_preorder_partial_batches%rowtype;
 choice_value text; used_credit bigint; alloc bigint; count_selected integer; total_units integer;
 ship integer; dtype text; nm text; digits text; addr text; path text; blocked boolean;
begin
 if is_device then
   d:=private.customer_device(p_session);
   if not private.customer_device_owns_preorder(d,'web',p_id::text)
     then raise exception 'Bu zakas qurilmangizga tegishli emas'; end if;
 else
   perform private.release_assert_owner(p_session,'web',p_id::text);
 end if;
 perform pg_advisory_xact_lock(hashtextextended('partial:'||p_id::text,28));
 select * into w from public.web_preorder_requests where id=p_id for update;
 if p_action='detail' then return private.web_preorder_partial_detail(p_id); end if;
 select * into b from private.web_preorder_partial_batches
 where preorder_id=p_id and status in ('prepared','awaiting_payment','proof_submitted')
 order by created_at desc limit 1 for update;
 if not found then raise exception 'Kutilayotgan qisman hisob topilmadi'; end if;
 if p_action='choose' then
   if b.status<>'prepared' then raise exception 'Avans tanlovi allaqachon saqlangan'; end if;
   choice_value:=p_payload->>'choice';
   if choice_value not in ('all','keep') then raise exception 'Avans taqsimotini tanlang'; end if;
   nm:=trim(coalesce(p_payload->>'recipient_name',''));
   digits:=regexp_replace(coalesce(p_payload->>'recipient_phone',''),'[^0-9]','','g');
   addr:=trim(coalesce(p_payload->>'address',''));
   dtype:=p_payload->>'delivery_type';
   if length(nm) not between 2 and 80 or digits !~ '^010[0-9]{8}$'
      or dtype not in ('택배','경산 직접수령','경산 무료배송')
      or length(addr)>500 or (dtype<>'경산 직접수령' and length(addr)<8)
      then raise exception 'Ism, telefon va manzilni tekshiring'; end if;
   if dtype='경산 무료배송' and addr !~ '경산' and lower(addr) !~ 'gyeongsan'
      then raise exception 'Gyeongsan manzilini kiriting'; end if;
   select coalesce(sum(deposit_applied),0) into used_credit
   from private.web_preorder_partial_batches where preorder_id=p_id and status='completed';
   select coalesce(sum((x->>'quantity')::int),0) into count_selected from jsonb_array_elements(b.items) x;
   select coalesce(sum((x->>'quantity')::int),0) into total_units from jsonb_array_elements(w.request_items) x;
   if choice_value='keep' and count_selected>=total_units-
      (select coalesce(sum((x->>'quantity')::int),0) from private.web_preorder_partial_batches h
        cross join lateral jsonb_array_elements(h.items) x
        where h.preorder_id=p_id and h.status='completed') then
        raise exception 'Qolgan kitob yo‘q. Barcha avansni ishlating'; end if;
   alloc:=case when choice_value='all' then greatest(w.deposit_amount::bigint-used_credit,0)
     else least(greatest(w.deposit_amount::bigint-used_credit,0),
         count_selected::bigint*w.deposit_per_book::bigint) end;
   select exists(select 1 from jsonb_array_elements(b.items) x
     join public.books k on k.id=(x->>'book_id')::uuid
     where k.discount_percent>0 and (k.discount_ends_at is null or k.discount_ends_at>now())
       and k.discount_free_delivery=false) into blocked;
   ship:=case when dtype in ('경산 직접수령','경산 무료배송') or (count_selected>=4 and not blocked)
     then 0 else 4000 end;
   update private.web_preorder_partial_batches set
     status='awaiting_payment',choice=choice_value,deposit_applied=alloc,shipping_fee=ship,
     amount_due=greatest(b.subtotal+ship-alloc,0),
     refund_due=greatest(alloc-b.subtotal-ship,0),
     recipient_name=nm,recipient_phone=digits,delivery_type=dtype,
     delivery_address=case when dtype='경산 직접수령' then dtype else addr end,
     updated_at=now() where id=b.id;
 elsif p_action='proof' then
   if b.status='proof_submitted' and b.proof_path=p_payload->>'path'
     then return private.web_preorder_partial_detail(p_id); end if;
   if b.status<>'awaiting_payment' or b.amount_due<=0 then raise exception 'To‘lov kerak emas yoki tanlov tasdiqlanmagan'; end if;
   path:=trim(coalesce(p_payload->>'path',''));
   if path !~ '^receipts/[A-Za-z0-9._/-]+$'
     or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=path)
     or not (
       (is_device and exists(select 1 from private.customer_device_receipts cr
           where cr.path=path and cr.device_id=d.id))
       or (not is_device and exists(select 1 from private.release_receipt_claims c
           where c.path=path and c.phone_key=public._customer_phone_key(w.phone)))
     )
     or exists(select 1 from public.orders where payment_proof_path=path)
     or exists(select 1 from private.release_preorder_invoices where balance_proof_path=path)
     then raise exception 'Chek topilmadi yoki avval ishlatilgan'; end if;
   update private.web_preorder_partial_batches
      set status='proof_submitted',proof_path=path,updated_at=now() where id=b.id;
 else raise exception 'Amal noto‘g‘ri'; end if;
 return private.web_preorder_partial_detail(p_id);
end $$;
revoke all on function public.customer_web_preorder_partial(text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.customer_web_preorder_partial(text,uuid,text,jsonb) to anon,authenticated,service_role;
