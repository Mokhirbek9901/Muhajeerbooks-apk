CREATE OR REPLACE FUNCTION public.admin_web_batch_line_list(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not coalesce(public.admin_verify(p_secret),false) then
   raise exception 'Admin tasdiqlanmadi';
 end if;
 return coalesce((
  select jsonb_agg(
    jsonb_build_object('id',l.id,'book_id',l.book_id,'title',b.title,
      'quantity',l.quantity,'unit_cost',l.unit_cost,
      'image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url),
      'suggested_price',l.suggested_price,'purchased_at',l.purchased_at,
      'note',l.note,'cost_origin',l.cost_origin,
      'inventory_applied',l.inventory_applied,'batch_import_id',l.batch_import_id,'batch_group_id',l.batch_group_id,
      'batch_name',coalesce(g.title,i.title,'Alohida partiya'),
      'batch_type',case when l.batch_import_id is not null then 'finance'
        when l.batch_group_id is not null then 'catalog' else 'legacy' end)
    order by l.purchased_at desc,l.id desc)
  from public.web_book_batches l
  join public.books b on b.id=l.book_id
  left join public.web_batch_imports i on i.id=l.batch_import_id
  left join public.web_batch_groups g on g.id=l.batch_group_id
 ),'[]'::jsonb);
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_web_batch_picker_data(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if not coalesce(public.admin_verify(p_secret),false) then
   raise exception 'Admin tasdiqlanmadi';
 end if;
 return jsonb_build_object(
  'books',coalesce((select jsonb_agg(jsonb_build_object(
       'id',b.id,'title',b.title,'cost_price',b.cost_price,
       'image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url),
       'price',b.price,'stock',b.stock,'is_active',b.is_active)
       order by lower(b.title))
       from public.books b),'[]'::jsonb),
  'historical',coalesce((
    select jsonb_agg(h.record order by h.sort_date desc,h.sort_id desc)
    from (
      select g.batch_date as sort_date, 0::bigint as sort_id,
        jsonb_build_object(
          'id',g.id,
          'title',g.title,'purchase_date',g.batch_date,
          'total_krw',(select sum(coalesce(f.amount,p.total_krw))
              from public.web_batch_imports p
              left join public.finance_expenses f on f.id=p.finance_expense_id
              where p.finance_group_id=g.id),
          'source','finance_group'
        ) as record
      from public.web_finance_batch_groups g
      where exists(select 1 from public.web_batch_imports p
        where p.finance_group_id=g.id)
      union all
      select p.purchase_date,p.id,
        jsonb_build_object('id',p.id,'title',p.title,
          'purchase_date',p.purchase_date,
          'total_krw',coalesce(f.amount,p.total_krw),
          'source',p.source)
      from public.web_batch_imports p
      left join public.finance_expenses f on f.id=p.finance_expense_id
      where p.finance_group_id is null
    ) h
  ),'[]'::jsonb),
  'groups',coalesce((select jsonb_agg(
      jsonb_build_object('id',g.id,'title',g.title,'batch_date',g.batch_date)
      order by g.batch_date desc,g.created_at desc)
      from public.web_batch_groups g),'[]'::jsonb),
  'transports',coalesce((select jsonb_agg(
    jsonb_build_object(
      'id',e.id,'expense_date',e.expense_date,
      'amount',e.amount,'note',e.note,'source',e.source,
      'batch_import_id',l.batch_import_id,'batch_group_id',l.batch_group_id,
      'linked_to',coalesce(fg.title,p.title,g.title),
      'linked_at',l.linked_at
    ) order by e.expense_date desc,e.created_at desc)
    from public.finance_expenses e
    left join public.web_batch_transport_links l on l.finance_expense_id=e.id
    left join public.web_batch_imports p on p.id=l.batch_import_id
    left join public.web_finance_batch_groups fg on fg.id=p.finance_group_id
    left join public.web_batch_groups g on g.id=l.batch_group_id
    where e.category='transport'),'[]'::jsonb)
 );
end; $function$;
