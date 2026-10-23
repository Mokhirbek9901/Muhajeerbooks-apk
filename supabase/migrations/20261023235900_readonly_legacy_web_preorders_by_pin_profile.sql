-- Preserve PIN-backed cross-device linking for known devices.
-- Recover older web preorders with missing installation IDs ONLY after an
-- active PIN session AND exact name + phone match against the PIN profile.
-- Legacy rows are intentionally summary-only, never payment/proof data and
-- never mutable. No native/stock/customer order updates.
CREATE OR REPLACE FUNCTION public.customer_pin_preorders(p_session text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare k text:=private.pin_session_phone(p_session); rows jsonb;
begin
 if k is null then raise exception 'PIN bilan kirishingiz kerak'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc),'[]'::jsonb)
 into rows from (
   select 'native'::text source,p.id::text id,p.book_id,
     coalesce(b.title,'Kitob') title,p.status,p.quantity,p.created_at,
     'pin'::text ownership,
     coalesce(h.quantity,0) reserved_quantity,
     case when r.preorder_id is null then null else
       jsonb_build_object('base_total',r.base_total,
         'extra_total',r.extra_total,'deposit_credit',r.deposit_credit,
         'amount_due',r.amount_due,'unit_price',r.unit_price,
         'shipping_fee',r.shipping_fee,'admin_note',r.admin_note,
         'payment_state',r.payment_state)
     end invoice
   from public.preorders p
   left join public.books b on b.id=p.book_id
   left join private.preorder_stock_holds h on h.preorder_id=p.id
   left join private.preorder_payment_requests r on r.preorder_id=p.id
   where exists(select 1 from private.customer_pin_devices d
     where d.phone_key=k and d.install_id=p.install_id)
     and public._customer_phone_key(p.phone)=k
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='native' and a.order_id=p.id::text)
   union all
   select 'web'::text,w.id::text,null::uuid,w.book_title,w.status,w.quantity,
     w.created_at,
     case when w.install_id is null then 'legacy'::text else 'pin'::text end,
     0::integer,null::jsonb
   from public.web_preorder_requests w
   where (
      exists(select 1 from private.customer_pin_devices d
        where d.phone_key=k and d.install_id=w.install_id)
      or (
        w.install_id is null
        and exists(
          select 1 from private.customer_pin_profiles profile
          where profile.phone_key=k
            and lower(regexp_replace(trim(profile.full_name),'\\s+',' ','g'))=
                lower(regexp_replace(trim(w.customer_name),'\\s+',' ','g'))
        )
      )
   )
     and public._customer_phone_key(w.phone)=k
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
   order by created_at desc limit 100
 ) t;
 return rows;
end;
$function$

;
