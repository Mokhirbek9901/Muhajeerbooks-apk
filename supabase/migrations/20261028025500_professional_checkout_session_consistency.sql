-- Give admins time to finish a quote (quotes expire in 30 minutes).
-- Existing sessions retain their prior expiry; a new code entry creates a new session.
alter table private.release_professional_sessions alter column expires_at
  set default (now()+interval '45 minutes');

-- Keep professional checkout isolated from any customer PIN session active
-- in the same browser/phone. Orders still require the original validated
-- professional token and a matching server-side quote.
CREATE OR REPLACE FUNCTION public.customer_release_quote(p_session text, p_order jsonb, p_admin_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare k text:=private.pin_session_phone(p_session); o public.orders%rowtype; qid uuid; professional boolean;
begin
 professional:=exists(select 1 from private.release_professional_sessions where token=p_admin_token and expires_at>now());
 -- Professional quotes belong only to their admin authorization, never to
 -- whichever customer PIN profile happens to be active on this device.
 if professional then k:='admin:'||p_admin_token::text; end if;
 if not professional and k is null then raise exception 'PIN bilan kiring'; end if;
 if not professional and public._customer_phone_key(p_order->>'phone')<>k then raise exception 'Profil telefonini ishlating'; end if;
 o:=jsonb_populate_record(null::public.orders,p_order||jsonb_build_object('source','app','status','new','entered_by_admin',professional));
 o:=private.release_prepare_order(o); o:=private.release_finalize_order(o);
 if professional and p_order?'manual_subtotal' then
  if (p_order->>'manual_subtotal')::integer not between 1 and 100000000 then raise exception 'Jami narx noto‘g‘ri'; end if;
  -- Manual orders still use trusted item quantities; manual price is explicit.
  o.subtotal:=(p_order->>'manual_subtotal')::integer; o.total:=o.subtotal+o.delivery_fee;
 end if;
 insert into private.release_checkout_quotes(phone_key,snapshot) values(coalesce(k,'admin:'||p_admin_token::text),to_jsonb(o)) returning id into qid;
 return to_jsonb(o)||jsonb_build_object('quote_id',qid,'expires_at',now()+interval '30 minutes');
end $function$
;

CREATE OR REPLACE FUNCTION public.customer_release_order(p_session text, p_quote_id uuid, p_order jsonb, p_admin_token uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare k text:=private.pin_session_phone(p_session); q private.release_checkout_quotes%rowtype; o public.orders%rowtype; oid uuid:=(p_order->>'id')::uuid; professional boolean; receipt_path text;
begin
 professional:=exists(select 1 from private.release_professional_sessions where token=p_admin_token and expires_at>now());
 if professional then k:='admin:'||p_admin_token::text; end if;
 if not professional and k is null then raise exception 'PIN bilan kiring'; end if;
 -- Preserve the old customer-session path for ordinary PIN orders.
 k:=coalesce(k,'admin:'||p_admin_token::text);
 perform pg_advisory_xact_lock(hashtextextended('checkout:'||oid::text,27));
 if exists(select 1 from private.release_order_owners where order_id=oid and phone_key=k) then
  select * into o from public.orders where id=oid; return to_jsonb(o);
 end if;
 if exists(select 1 from public.orders where id=oid) then raise exception 'Bu buyurtma IDsi boshqa profilga tegishli'; end if;
 select * into q from private.release_checkout_quotes where id=p_quote_id and phone_key=k for update;
 if not found or q.expires_at<=now() then raise exception 'Hisob muddati tugadi. Summani qayta tekshiring'; end if;
 o:=jsonb_populate_record(null::public.orders,q.snapshot);
 if not professional and public._customer_phone_key(o.phone)<>k then raise exception 'Telefon mos emas'; end if;
 receipt_path:=coalesce(p_order->>'payment_proof_path','');
 if not professional and not exists(select 1 from private.release_receipt_claims where release_receipt_claims.path=receipt_path and phone_key=k) then raise exception 'Chek profilingizga biriktirilmagan'; end if;
 if receipt_path<>'' and (exists(select 1 from public.orders where payment_proof_path=receipt_path) or exists(select 1 from public.preorders where payment_proof_path=receipt_path) or exists(select 1 from public.web_preorder_requests where payment_proof_path=receipt_path)) then raise exception 'Bu chek boshqa zakasda ishlatilgan'; end if;
 insert into private.release_order_owners values(oid,k,p_quote_id);
 if professional then insert into private.release_admin_orders values(oid); end if;
 insert into public.orders(id,customer_name,phone,address,delivery_type,delivery_fee,subtotal,total,status,source,items,bundle_selections,payment_proof_path,payment_submitted_at,instagram_handle,order_note,entered_by_admin,payment_status)
 values(oid,o.customer_name,o.phone,o.address,o.delivery_type,o.delivery_fee,o.subtotal,o.total,'new','app',o.items,o.bundle_selections,receipt_path,case when receipt_path='' then null else now() end,o.instagram_handle,o.order_note,professional,case when professional then coalesce(o.payment_status,'paid') else 'paid' end)
 returning * into o;
 return to_jsonb(o);
end $function$
;
