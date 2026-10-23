-- Archive exactly two owner-identified test/cancelled preorders from admin lists.
-- Preserve original rows, deposits and event history; no DELETE or stock changes.
create table if not exists private.admin_preorder_hidden (
  source text not null check (source in ('native','web')),
  order_id text not null,
  reason text not null,
  hidden_at timestamptz not null default now(),
  primary key (source,order_id)
);
revoke all on private.admin_preorder_hidden from public,anon,authenticated;
insert into private.admin_preorder_hidden(source,order_id,reason)
values
  ('native','1','owner_removed_blank_test_preorder_20261023'),
  ('web','4c5fd551-d82a-4ee6-917c-cfb581e9c950','owner_removed_cancelled_web_preorder_20261023')
on conflict (source,order_id) do nothing;

-- Preserve all current business logic; only exclude archived IDs from admin lists.
CREATE OR REPLACE FUNCTION public.admin_preorders_all_list(p_secret text, p_limit integer DEFAULT 200, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_rows jsonb; v_total integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_limit is null or p_limit not between 1 and 200 or
     p_offset is null or p_offset < 0 then
    raise exception 'Sahifalash parametrlari noto‘g‘ri';
  end if;
  select count(*)::integer into v_total from public.preorders;
  select coalesce(
    jsonb_agg(to_jsonb(t) order by t.created_at desc, t.id desc),
    '[]'::jsonb
  ) into v_rows
  from (
    select p.id, p.book_id, coalesce(b.title,'Kitob') as title,
      p.customer_name, p.phone, p.quantity, p.status,
      p.deposit_amount, p.payment_proof_path, p.note,
      coalesce(b.preorder_arrival_note,'') as arrival_note,
      p.created_at
    from public.preorders p
    left join public.books b on b.id=p.book_id
    where not exists (select 1 from private.admin_preorder_hidden h
      where h.source='native' and h.order_id=p.id::text)
    order by p.created_at desc,p.id desc
    limit p_limit offset p_offset
  ) as t;
  return jsonb_build_object('rows',v_rows,'total',v_total);
end;
$function$

CREATE OR REPLACE FUNCTION public.admin_web_preorder_manage(p_secret text, p_action text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s public.web_preorder_settings%rowtype; r public.web_preorder_requests%rowtype;
 enabled_value boolean; arrival text; amount integer; batch integer; target text; note_value text;
begin
 if public._admin_secret_ok(p_secret) is not true then raise exception 'Ruxsat yo‘q'; end if;
 if p_action='settings' then return public.web_preorder_config();
 elsif p_action='save' then
  enabled_value:=(p_payload->>'enabled')::boolean; arrival:=trim(coalesce(p_payload->>'arrival_note',''));
  amount:=(p_payload->>'deposit_amount')::integer; batch:=(p_payload->>'batch_quantity')::integer;
  if enabled_value is null or amount is null or batch is null or length(arrival)>200 or
    (enabled_value and arrival='') or amount not between 5000 and 10000000 or batch not between 0 and 100000 then
   raise exception 'Sana, avans va sonni tekshiring.'; end if;
  select * into s from public.web_preorder_settings where id for update;
  if (p_payload->>'revision')::bigint is distinct from s.revision then
   raise exception 'Sozlamalar boshqa oynada o‘zgargan. Sahifani yangilang.'; end if;
  update public.web_preorder_settings set enabled=enabled_value,arrival_note=arrival,deposit_amount=amount,
   batch_quantity=batch,revision=revision+1,updated_at=now() where id;
  return public.web_preorder_config();
 elsif p_action='list' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select req.*,
    (select e.delivery_state from private.web_preorder_events e where e.preorder_id=req.id and e.audience='customer' order by version desc limit 1) as notification_state,
    (select coalesce(jsonb_agg(jsonb_build_object('status',h.status,'created_at',h.created_at,'message',h.body) order by h.version desc),'[]') from private.web_preorder_events h where h.preorder_id=req.id and h.audience='customer') as history
    from public.web_preorder_requests req
    where not exists (select 1 from private.admin_preorder_hidden h
      where h.source='web' and h.order_id=req.id::text)
    order by req.created_at desc,req.id desc
      limit least(200,greatest(1,coalesce((p_payload->>'limit')::integer,200)))
      offset greatest(0,coalesce((p_payload->>'offset')::integer,0))) x),'[]');
 elsif p_action='status' then
  target:=p_payload->>'status'; note_value:=trim(coalesce(p_payload->>'note',''));
  if target is null or target not in ('waiting','accepted','arrived','cancelled') or length(note_value)>500 then raise exception 'Noto‘g‘ri holat'; end if;
  select * into r from public.web_preorder_requests q where q.id=(p_payload->>'id')::uuid for update;
  if not found then raise exception 'Buyurtma topilmadi'; end if;
  if r.status=target then return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',true); end if;
  if (p_payload->>'version')::integer is distinct from r.status_version then raise exception 'Holat boshqa oynada o‘zgargan. Ro‘yxatni yangilang.'; end if;
  if not ((r.status='waiting' and target in ('accepted','cancelled')) or
    (r.status='accepted' and target in ('arrived','cancelled')) or
    (r.status='arrived' and target='cancelled') or
    (r.status='cancelled' and target='waiting')) then raise exception 'Avval buyurtmani qabul qiling yoki bekor qilingan buyurtmani qayta oching.'; end if;
  if target in ('cancelled','waiting') and length(note_value)<3 then raise exception 'Sababini yozing (kamida 3 belgi).'; end if;
  update public.web_preorder_requests q set status=target,status_note=note_value,status_version=q.status_version+1,updated_at=now() where q.id=r.id returning * into r;
  return jsonb_build_object('status',r.status,'version',r.status_version,'duplicate',false,'inbox_created',true);
 end if;
 raise exception 'Noto‘g‘ri amal';
end;
$function$

CREATE OR REPLACE FUNCTION public.admin_merchandising_insights(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pre jsonb; v_req jsonb; v_search jsonb; v_restock jsonb; v_bundle_sales jsonb; v_bundle_summary jsonb;
begin
 if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
 select coalesce(jsonb_agg(x order by (x->>'created_at') desc),'[]'::jsonb) into v_pre from (
   select jsonb_build_object('id',p.id,'book_id',p.book_id,'title',b.title,'customer_name',p.customer_name,'phone',p.phone,
     'quantity',p.quantity,'status',p.status,'deposit_amount',p.deposit_amount,'payment_proof_path',p.payment_proof_path,
     'note',p.note,'arrival_note',b.preorder_arrival_note,'created_at',p.created_at) x
   from public.preorders p join public.books b on b.id=p.book_id
   where p.status='waiting' and not exists (select 1 from private.admin_preorder_hidden h
     where h.source='native' and h.order_id=p.id::text)
   order by p.created_at desc limit 100
 ) q;
 select coalesce(jsonb_agg(x order by (x->>'created_at') desc),'[]'::jsonb) into v_req from (
   select jsonb_build_object('id',r.id,'title',r.title,'author',r.author,'phone',r.phone,'status',r.status,'created_at',r.created_at) x
   from public.book_requests r order by r.created_at desc limit 100
 ) q;
 select coalesce(jsonb_agg(jsonb_build_object('query',q,'count',cnt,'last_at',last_at) order by cnt desc,last_at desc),'[]'::jsonb)
 into v_search from (
   select lower(trim(query)) q,count(*) cnt,max(created_at) last_at
   from public.search_misses where created_at>=now()-interval '90 days'
   group by lower(trim(query)) order by cnt desc,max(created_at) desc limit 50
 ) s;
 select coalesce(jsonb_agg(jsonb_build_object('book_id',id,'title',title,'stock',stock,'waiting',waiting,'sold_30d',sold_30d,'score',waiting*4+sold_30d) order by waiting*4+sold_30d desc),'[]'::jsonb)
 into v_restock from (
   select b.id,b.title,b.stock,count(distinct rs.install_id) filter(where rs.notified_at is null)::int waiting,
     coalesce((select sum(case when coalesce(i->>'quantity','') ~ '^[0-9]+$' then (i->>'quantity')::int else 0 end)
       from public.orders o cross join lateral jsonb_array_elements(o.items)i
       where o.status in ('accepted','paid','shipping','done') and o.created_at>=now()-interval '30 days'
         and coalesce(i->>'book_id','')=b.id::text),0)::int sold_30d
   from public.books b left join public.restock_subscriptions rs on rs.book_id=b.id
   where b.is_active=true group by b.id,b.title,b.stock
 ) x where waiting>0 or stock<=2 or sold_30d>0 limit 50;
 select coalesce(jsonb_agg(jsonb_build_object(
   'order_id',o.id,'order_number',coalesce(o.display_order_number,o.order_number),'title',coalesce(s->>'title','Kitoblar seti'),
   'set_price',coalesce((s->>'price')::int,0),'regular_total',coalesce((s->>'regular_total')::int,0),
   'saving',coalesce((s->>'saving')::int,0),'book_count',coalesce((s->>'book_count')::int,0),
   'delivery_included',coalesce((s->>'delivery_included')::boolean,false),'order_delivery_fee',o.delivery_fee,
   'order_total',o.total,'sold_at',coalesce(o.updated_at,o.created_at)
 ) order by coalesce(o.updated_at,o.created_at) desc),'[]'::jsonb)
 into v_bundle_sales from public.orders o
 cross join lateral jsonb_array_elements(coalesce(o.bundle_selections,'[]'::jsonb)) s
 where o.status in ('accepted','paid','shipping','done');
 select jsonb_build_object('sets_sold',count(*),'set_revenue',coalesce(sum(coalesce((s->>'price')::int,0)),0),
   'set_savings',coalesce(sum(coalesce((s->>'saving')::int,0)),0),
   'shipping_included_sets',count(*) filter(where coalesce((s->>'delivery_included')::boolean,false)),
   'shipping_separate_sets',count(*) filter(where not coalesce((s->>'delivery_included')::boolean,false)))
 into v_bundle_summary from public.orders o
 cross join lateral jsonb_array_elements(coalesce(o.bundle_selections,'[]'::jsonb)) s
 where o.status in ('accepted','paid','shipping','done');
 return jsonb_build_object('preorders',v_pre,'requests',v_req,'search_misses',v_search,'restock',v_restock,
   'bundle_sales',v_bundle_sales,'bundle_summary',coalesce(v_bundle_summary,'{}'::jsonb));
end $function$

-- Only in-app orders may have tracking information entered/edited.
CREATE OR REPLACE FUNCTION public.admin_update_order_tracking(p_secret text, p_id uuid, p_carrier text, p_tracking_number text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_carrier text := lower(trim(coalesce(p_carrier,'')));
  v_tracking text := regexp_replace(coalesce(p_tracking_number,''), '[^0-9A-Za-z-]', '', 'g');
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;
  if v_carrier not in ('','cj','epost','lotte','hanjin','logen','other') then
    raise exception 'Pochta turi noto‘g‘ri';
  end if;
  if char_length(v_tracking) > 80 then
    raise exception 'Kuzatuv raqami juda uzun';
  end if;
  if not exists(select 1 from public.orders where id=p_id) then
    raise exception 'Buyurtma topilmadi';
  end if;
  if not exists(select 1 from public.orders where id=p_id
    and lower(trim(coalesce(source,'')))='app') then
    raise exception 'Tracking faqat ilovadan qilingan buyurtmalarga kiritiladi';
  end if;

  update public.orders
     set carrier = v_carrier,
         tracking_number = v_tracking,
         tracking_updated_at = case when v_tracking='' then null else now() end,
         updated_at = now()
   where id = p_id;
end;
$function$

