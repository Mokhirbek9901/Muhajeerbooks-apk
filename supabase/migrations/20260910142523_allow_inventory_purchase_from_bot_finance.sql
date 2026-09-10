create or replace function public.bot_add_finance_expense(
  p_secret text,
  p_amount integer,
  p_category text default 'postage'::text,
  p_note text default ''::text,
  p_expense_date date default null::date
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_category text := lower(trim(coalesce(p_category,'postage')));
  v_id uuid;
begin
  perform 1 from public.bot_sales_list(p_secret, 1) limit 1;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Xarajat summasi noto‘g‘ri';
  end if;
  if v_category not in (
    'postage','packaging','ads','transport','inventory_purchase','other'
  ) then
    raise exception 'Xarajat turi noto‘g‘ri';
  end if;

  insert into public.finance_expenses(
    expense_date, category, amount, note, source
  ) values (
    coalesce(p_expense_date,(now() at time zone 'Asia/Seoul')::date),
    v_category,
    p_amount,
    left(trim(coalesce(p_note,'')),300),
    'telegram'
  ) returning id into v_id;

  return jsonb_build_object('id',v_id,'ok',true);
end;
$function$;
