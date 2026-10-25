-- Freeze purchase cost and checkout price when a sale first becomes recognized.
-- Neither a later purchase batch nor edits to books.cost_price may alter it.
-- Existing sales are backfilled from sales_log without changing any totals.

create table if not exists private.book_sale_profit_snapshots (
  order_id uuid not null references public.orders(id) on delete cascade,
  item_index integer not null,
  unit_index integer not null,
  book_id uuid,
  unit_price integer not null check (unit_price >= 0),
  unit_cost integer not null check (unit_cost >= 0),
  cost_known boolean not null default false,
  first_sold_at timestamptz not null,
  primary key(order_id,item_index,unit_index)
);

insert into private.book_sale_profit_snapshots(
  order_id,item_index,unit_index,book_id,unit_price,unit_cost,cost_known,first_sold_at)
select s.order_id,s.item_index,s.unit_index,s.book_id,
  greatest(0,s.unit_price),greatest(0,s.unit_cost),
  s.unit_cost>0,s.sold_at
from public.sales_log s
where s.order_id is not null
on conflict(order_id,item_index,unit_index) do nothing;

create or replace function private.freeze_book_profit_on_sale()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_old private.book_sale_profit_snapshots%rowtype;
  v_cost integer;
begin
  -- Stable logical unit identity across sales-log rebuilds (which delete
  -- and reinsert the same rows). Do not recalculate recognized sales.
  select * into v_old from private.book_sale_profit_snapshots
  where order_id=new.order_id and item_index=new.item_index
    and unit_index=new.unit_index;
  if found then
    new.unit_price:=v_old.unit_price;
    new.unit_cost:=v_old.unit_cost;
    return new;
  end if;

  -- IMPORTANT: Capture cost at the recognition of the sale (accepted/paid/
  -- shipping), not when the cart or a new order was first created.
  -- This is the current catalog purchase cost regardless of batch changes.
  v_cost:=null;
  if new.book_id is not null then
    select greatest(0,b.cost_price) into v_cost
    from public.books b where b.id=new.book_id;
  end if;
  -- If the book was deleted/unlinked, the order's saved cost is the only
  -- available historic fact. Never treat missing purchase cost as profit.
  v_cost:=coalesce(v_cost,greatest(0,coalesce(new.unit_cost,0)));

  new.unit_price:=greatest(0,coalesce(new.unit_price,0));
  new.unit_cost:=v_cost;
  insert into private.book_sale_profit_snapshots (
    order_id,item_index,unit_index,book_id,unit_price,unit_cost,cost_known,first_sold_at
  ) values (
    new.order_id,new.item_index,new.unit_index,new.book_id,
    new.unit_price,new.unit_cost,new.unit_cost>0,
    coalesce(new.sold_at,now())
  ) on conflict(order_id,item_index,unit_index) do nothing;

  return new;
end;
$$;

drop trigger if exists freeze_book_profit_on_sale on public.sales_log;
create trigger freeze_book_profit_on_sale
before insert on public.sales_log for each row
execute function private.freeze_book_profit_on_sale();

-- Stable read-only profit report for the owner. Historical old sales
-- without a book_id remain in the global total, not guessed onto a title.
-- All times in filters use the shop's Korea time zone.
create or replace function public.admin_book_profit_report(
  p_secret text, p_period text default 'all'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_start date;
  v_end date;
  v_result jsonb;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_period not in ('all','today','yesterday','week','month','previous_month') then
    raise exception 'Davr filtri noto‘g‘ri';
  end if;
  if p_period='today' then
    v_start:=v_today; v_end:=v_today+1;
  elsif p_period='yesterday' then
    v_start:=v_today-1; v_end:=v_today;
  elsif p_period='week' then
    v_start:=v_today-6; v_end:=v_today+1;
  elsif p_period='month' then
    v_start:=date_trunc('month',v_today::timestamp)::date;
    v_end:=(v_start+interval '1 month')::date;
  elsif p_period='previous_month' then
    v_end:=date_trunc('month',v_today::timestamp)::date;
    v_start:=(v_end-interval '1 month')::date;
  end if;

  with sale_rows as (
    select s.*,
      coalesce(ps.cost_known,s.unit_cost>0) known
    from public.sales_log s
    left join private.book_sale_profit_snapshots ps
      on ps.order_id=s.order_id
      and ps.item_index=s.item_index and ps.unit_index=s.unit_index
    where (v_start is null or (s.sold_at at time zone 'Asia/Seoul')::date>=v_start)
      and (v_end is null or (s.sold_at at time zone 'Asia/Seoul')::date<v_end)
  ), by_book as (
    select book_id,
      count(*)::integer quantity,
      sum(unit_price)::bigint revenue,
      coalesce(sum(unit_price-unit_cost) filter(where known),0)::bigint profit,
      count(*) filter(where not known)::integer unknown_count
    from sale_rows group by book_id
  )
  select jsonb_build_object(
    'period',p_period,'generated_at',now(),
    'summary',(select jsonb_build_object(
      'sold',count(*),'revenue',coalesce(sum(unit_price),0),
      'profit',coalesce(sum(unit_price-unit_cost) filter(where known),0),
      'unknown_cost_sales',count(*) filter(where not known)
    ) from sale_rows),
    'books',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',b.id,'title',b.title,'author',b.author,'category',b.category,
        'stock',b.stock,'cost_price',b.cost_price,
        'sale_price',case
          when b.discount_percent>0
            and (b.discount_ends_at is null or b.discount_ends_at>now())
          then round(b.price*(100-b.discount_percent)/100.0)::integer
          else b.price end,
        'image_url',coalesce(nullif(b.thumbnail_url,''),b.image_url),
        'is_active',b.is_active,
        'sold',coalesce(a.quantity,0),'revenue',coalesce(a.revenue,0),
        'profit',coalesce(a.profit,0),'unknown_cost_sales',coalesce(a.unknown_count,0)
      ) order by b.title)
      from public.books b left join by_book a on a.book_id=b.id
    ),'[]'::jsonb),
    'unlinked',(select jsonb_build_object(
      'sold',coalesce(quantity,0),'revenue',coalesce(revenue,0),
      'profit',coalesce(profit,0),'unknown_cost_sales',coalesce(unknown_count,0)
    ) from by_book where book_id is null),
    'daily',coalesce((
      select jsonb_agg(jsonb_build_object(
        'date',date_key,'sold',qty,'revenue',revenue,'profit',profit)
        order by date_key)
      from (
        select (sold_at at time zone 'Asia/Seoul')::date date_key,
          count(*) qty,sum(unit_price)::bigint revenue,
          coalesce(sum(unit_price-unit_cost) filter(where known),0)::bigint profit
        from sale_rows group by 1 order by 1
      ) d
    ),'[]'::jsonb),
    'recent_sales',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'book_id',s.book_id,'title',s.title,
        'unit_price',s.unit_price,'unit_cost',s.unit_cost,
        'cost_known',s.known,'sold_at',s.sold_at,
        'source',s.source
      ) order by s.sold_at desc,s.id desc)
      from (select * from sale_rows order by sold_at desc,id desc limit 250) s
    ),'[]'::jsonb),
    'legacy_sales_count',(select count(*) from public.legacy_sales_history)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on private.book_sale_profit_snapshots from public,anon,authenticated;
revoke execute on function public.admin_book_profit_report(text,text)
  from public,anon,authenticated;
grant execute on function public.admin_book_profit_report(text,text)
  to anon,authenticated,service_role;

comment on function public.admin_book_profit_report(text,text) is
 'Admin-only report: each realized sale retains original unit_price/unit_cost. Costless sales are explicitly excluded from verified profit.';
