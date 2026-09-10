create or replace function public.admin_update_finance_expense(
  p_secret text,
  p_id uuid,
  p_amount integer,
  p_category text,
  p_note text default ''::text
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

  update public.finance_expenses
     set category = v_category,
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

grant execute on function public.admin_update_finance_expense(text,uuid,integer,text,text) to anon, authenticated;
