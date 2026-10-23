-- Prevent forgotten-PIN profile data leaking through legacy install-only
-- customer endpoints after that installation was linked to PIN.
CREATE OR REPLACE FUNCTION public.customer_preorder_balance_list(p_install_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb;
begin
  if length(trim(coalesce(p_install_id,'')))<12
    or length(p_install_id)>120 then raise exception 'Qurilma ID noto‘g‘ri'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
    into v_rows from (
      select p.id,p.book_id,p.status,p.quantity,p.deposit_amount,p.created_at,
        coalesce(b.title,'Kitob') title,coalesce(b.image_url,'') image_url,
        coalesce(h.quantity,0) reserved_quantity,
        case when r.preorder_id is not null then
          jsonb_build_object('base_total',r.base_total,
            'extra_total',r.extra_total,'deposit_credit',r.deposit_credit,
            'amount_due',r.amount_due,'unit_price',r.unit_price,
            'shipping_fee',r.shipping_fee,'admin_note',r.admin_note,
            'payment_state',r.payment_state,
            'extras',coalesce((select jsonb_agg(
              jsonb_build_object('book_id',ex.book_id,'title',bx.title,
                'quantity',ex.quantity,'unit_price',ex.unit_price)
              order by ex.created_at,ex.book_id)
             from private.preorder_extra_holds ex
             join public.books bx on bx.id=ex.book_id
             where ex.preorder_id=p.id),'[]'::jsonb))
          else null end as invoice
      from public.preorders p
      left join public.books b on b.id=p.book_id
      left join private.preorder_stock_holds h on h.preorder_id=p.id
      left join private.preorder_payment_requests r on r.preorder_id=p.id
      where p.install_id=trim(p_install_id)
        and not exists(select 1 from private.customer_pin_devices x where x.install_id=p.install_id)
       and not exists (select 1 from private.admin_preorder_hidden x
         where x.source='native' and x.order_id=p.id::text)
      order by p.created_at desc limit 60
    ) x;
  return v_rows;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.customer_preorder_discovery(p_install_id text, p_name text DEFAULT ''::text, p_phone text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id text:=trim(coalesce(p_install_id,'')); v_records jsonb;
begin
 if length(v_id) not between 12 and 120 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
 into v_records from (
  select 'native'::text source,p.id::text id,coalesce(b.title,'Kitob') title,
   p.status,p.quantity,p.created_at,'device'::text ownership
   from public.preorders p left join public.books b on b.id=p.book_id
   where p.install_id=v_id
    and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
    and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web'::text,w.id::text,w.book_title,w.status,w.quantity,w.created_at,
   'device'::text
   from public.web_preorder_requests w
   where w.install_id=v_id
    and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
    and not exists(
     select 1 from private.admin_preorder_hidden a
     where a.source='web' and a.order_id=w.id::text)
  order by created_at desc limit 80
 ) x;
 return v_records;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.customer_preorder_activity_list(p_install_id text, p_name text DEFAULT ''::text, p_phone text DEFAULT ''::text, p_limit integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id text:=trim(coalesce(p_install_id,'')); v_rows jsonb;
begin
 if length(v_id) not between 12 and 120 or
   coalesce(p_limit,0) not between 1 and 100 then
   raise exception 'Qurilma ma’lumoti noto‘g‘ri'; end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.created_at desc,v.id desc),'[]'::jsonb)
 into v_rows from (
  select 'native:'||e.id::text id,'native'::text source,p.id::text preorder_id,
   e.event_type,e.title,e.message,e.created_at
   from private.customer_preorder_events e
   join public.preorders p on p.id=e.preorder_id
   where p.install_id=v_id
    and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
    and not exists(
    select 1 from private.admin_preorder_hidden a
    where a.source='native' and a.order_id=p.id::text)
  union all
  select 'web:'||e.id::text,'web'::text,w.id::text,
   e.status,case e.status when 'accepted' then 'Zakazingiz qabul qilindi ✅'
     when 'arrived' then 'Kitobingiz keldi 📚'
     else 'Oldindan zakaz holati o‘zgardi' end,
   'Oldindan zakazlarim bo‘limini tekshiring.'::text,e.created_at
   from private.web_preorder_events e
   join public.web_preorder_requests w on w.id=e.preorder_id
   where e.audience='customer' and w.install_id=v_id
     and not exists(select 1 from private.customer_pin_devices d where d.install_id=v_id)
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
  order by created_at desc,id desc limit p_limit
 ) v;
 return v_rows;
end;
$function$
;

-- Require a valid PIN session for protected installations. Details can be
-- accessed only after successful PIN entry, not by typing a phone and name.
create or replace function public.customer_pin_preorders(p_session text)
returns jsonb language plpgsql security definer set search_path=''
as $$
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
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='native' and a.order_id=p.id::text)
   union all
   select 'web'::text,w.id::text,null::uuid,w.book_title,w.status,w.quantity,
     w.created_at,'pin'::text,0::integer,null::jsonb
   from public.web_preorder_requests w
   where exists(select 1 from private.customer_pin_devices d
     where d.phone_key=k and d.install_id=w.install_id)
     and not exists(select 1 from private.admin_preorder_hidden a
      where a.source='web' and a.order_id=w.id::text)
   order by created_at desc limit 100
 ) t;
 return rows;
end;
$$;
revoke all on function public.customer_pin_preorders(text) from public,anon,authenticated;
grant execute on function public.customer_pin_preorders(text) to service_role;
