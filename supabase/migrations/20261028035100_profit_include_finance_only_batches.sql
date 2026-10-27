-- Show historical consolidated finance batches in expected-profit report even
-- before their itemized books have been attributed; do not invent profit.
CREATE OR REPLACE FUNCTION public.admin_book_profit_batches(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_report jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;

  with rows as (
    select bt.id,
      bt.book_id,
      b.title as book_title,
      bt.quantity,
      b.stock as catalog_stock,
      bt.unit_cost,
      bt.purchased_at,
      bt.batch_group_id,
      coalesce(g.title,fg.title,to_char(bt.purchased_at,'DD.MM.YYYY')||' partiyasi') as group_title,
      coalesce(bt.batch_group_id::text,
        'finance:'||fg.id::text,'date:'||bt.purchased_at::text) as group_key,
      coalesce(g.batch_date,fg.batch_date,bt.purchased_at) as group_date,
      (case when b.discount_percent>0
        and (b.discount_ends_at is null or b.discount_ends_at>now())
        then round(b.price*(100-b.discount_percent)/100.0)::integer
        else b.price end) as sale_price
    from public.web_book_batches bt
    join public.books b on b.id=bt.book_id
    left join public.web_batch_groups g on g.id=bt.batch_group_id
    left join public.web_batch_imports wi on wi.id=bt.batch_import_id
    left join public.web_finance_batch_groups fg on fg.id=wi.finance_group_id
  ), ranked as (
    select r.*, coalesce(sum(r.quantity::bigint) over (
      partition by r.book_id
      order by r.purchased_at desc,r.id desc
      rows between unbounded preceding and 1 preceding
    ),0)::bigint as newer_lot_units
    from rows r
  ), balances as (
    select r.*,
      greatest(least(
        greatest(coalesce(r.catalog_stock,0),0)::bigint-r.newer_lot_units,
        r.quantity::bigint
      ),0)::bigint as estimated_remaining_units
    from ranked r
  ), calculations as (
    select r.*,
      (r.quantity::bigint-r.estimated_remaining_units)::bigint
        as estimated_sold_units,
      case when unit_cost>0 and sale_price>0
        then ((sale_price::bigint-unit_cost::bigint)*quantity::bigint)
        else null end as projected_profit
    from balances r
  ), grouped as (
    select group_key,max(group_title) as title,
      max(group_date) as group_date,
      count(*)::integer as book_rows,
      count(distinct book_id)::integer as book_titles,
      sum(quantity)::bigint as purchased_units,
      sum(estimated_sold_units)::bigint as estimated_sold_units,
      sum(estimated_remaining_units)::bigint as estimated_remaining_units,
      sum(unit_cost::bigint*quantity)::bigint as total_purchase_cost,
      coalesce(sum(projected_profit),0)::bigint as projected_profit,
      count(*) filter(where projected_profit is null)::integer as unpriced_rows
    from calculations group by group_key
  )
  select jsonb_build_object(
    'groups',coalesce((
      select jsonb_agg(jsonb_build_object(
        'group_key',group_key,'title',title,'date',group_date,
        'book_rows',book_rows,'book_titles',book_titles,
        'purchased_units',purchased_units,
        'estimated_sold_units',estimated_sold_units,
        'estimated_remaining_units',estimated_remaining_units,
        'estimated_sold_percent',case when purchased_units>0
          then round(estimated_sold_units::numeric*100/purchased_units,1)
          else 0 end,
        'total_purchase_cost',total_purchase_cost,
        'projected_profit',projected_profit,
        'unpriced_rows',unpriced_rows
      ) order by group_date desc,title)
      from grouped
    ),'[]'::jsonb) || coalesce((
      -- Finance-linked batches must remain visible before their book-by-book
      -- receipts are known. No invented quantity, margin or FIFO sold units.
      select jsonb_agg(jsonb_build_object(
        'group_key','finance:'||fg.id::text,
        'title',fg.title,'date',fg.batch_date,
        'book_rows',0,'book_titles',0,
        'purchased_units',0,'estimated_sold_units',0,
        'estimated_remaining_units',0,'estimated_sold_percent',null,
        'total_purchase_cost',null,'projected_profit',null,
        'unpriced_rows',0,'missing_lot_details',true,
        'finance_purchase_count',(
          select count(*) from public.web_batch_imports i
          where i.finance_group_id=fg.id
        ),
        'finance_recorded_cost',(
          select coalesce(sum(coalesce(f.amount,i.total_krw)),0)
          from public.web_batch_imports i
          left join public.finance_expenses f on f.id=i.finance_expense_id
          where i.finance_group_id=fg.id
        )
      ) order by fg.batch_date desc,fg.title)
      from public.web_finance_batch_groups fg
      where exists(select 1 from public.web_batch_imports i
        where i.finance_group_id=fg.id)
      and not exists(select 1 from public.web_book_batches bt
        join public.web_batch_imports i on i.id=bt.batch_import_id
        where i.finance_group_id=fg.id)
    ),'[]'::jsonb),
    'lots',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'group_key',group_key,
        'book_id',book_id,'book_title',book_title,
        'quantity',quantity,
        'estimated_sold_units',estimated_sold_units,
        'estimated_remaining_units',estimated_remaining_units,
        'unit_cost',unit_cost,
        'sale_price',sale_price,'purchased_at',purchased_at,
        'projected_profit',projected_profit
      ) order by purchased_at desc,id desc)
      from calculations
    ),'[]'::jsonb),
    'allocation_method','fifo_catalog_stock_estimate',
    'allocation_note',
      'FIFO qoidasi: katalogdagi hozirgi qoldiq har bir kitob uchun eng yangi partiyalardan orqaga qarab joylashtiriladi. Demak, chiqim avval eng eski qolgan partiyadan ayriladi. Bu hisobiy chiqim: eski buyurtmalar, buyurtma zaxiralari, qaytarish va qo‘lda ombor tuzatishlari sotuvdan alohida belgilanmaganligi sabab aynan sotilgan son deb tasdiqlab bo‘lmaydi. Kitob tannarxi va moliya yozuvlari o‘zgartirilmaydi.',
    'generated_at',now()
  ) into v_report;
  return v_report;
end;
$function$
;
