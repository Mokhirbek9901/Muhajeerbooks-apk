drop function if exists public.admin_update_finance_expense(text, uuid, integer, text, text);

create or replace function public.admin_update_finance_expense(
  p_secret text,
  p_id uuid,
  p_amount integer,
  p_category text,
  p_note text default ''::text,
  p_expense_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text := lower(trim(coalesce(p_category, '')));
  v_updated integer := 0;
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;
  if p_id is null then
    raise exception 'Xarajat topilmadi';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Xarajat summasi noto‘g‘ri';
  end if;
  if v_category not in ('postage','packaging','ads','transport','inventory_purchase','other') then
    raise exception 'Xarajat turi noto‘g‘ri';
  end if;
  if p_expense_date is not null and p_expense_date > (now() at time zone 'Asia/Seoul')::date then
    raise exception 'Xarajat sanasi kelajakda bo‘lishi mumkin emas';
  end if;

  update public.finance_expenses
     set expense_date = coalesce(p_expense_date, expense_date),
         category = v_category,
         amount = p_amount,
         note = left(trim(coalesce(p_note, '')), 300)
   where id = p_id;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Xarajat topilmadi';
  end if;

  return jsonb_build_object('id', p_id, 'ok', true);
end;
$$;

revoke all on function public.admin_update_finance_expense(text, uuid, integer, text, text, date) from public;
grant execute on function public.admin_update_finance_expense(text, uuid, integer, text, text, date) to anon, authenticated;
