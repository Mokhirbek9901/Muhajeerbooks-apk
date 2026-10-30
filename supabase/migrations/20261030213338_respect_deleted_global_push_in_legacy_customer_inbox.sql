-- An admin-soft-deleted global push must not reappear in legacy client inboxes.
CREATE OR REPLACE FUNCTION public.customer_release_inbox(p_session text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, title text, body text, sent_at timestamp with time zone, kind text, order_number bigint, order_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare k text:=private.pin_session_phone(p_session);
begin
 if k is null then raise exception 'PIN bilan kiring'; end if;
 return query with combined as (
 select m.id,m.title,m.body,m.sent_at,'global'::text,null::bigint,null::uuid from public.push_messages m where m.sent_at is not null and m.deleted_at is null
 union all select m.id,m.title,m.body,m.sent_at,m.kind,m.order_number,m.order_id from public.customer_push_messages m where public._customer_phone_key(m.phone)=k
 ) select * from combined order by 4 desc limit least(greatest(p_limit,1),100);
end $function$

