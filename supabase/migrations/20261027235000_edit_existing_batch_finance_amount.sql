-- Correct an already-booked finance expense directly from its historical batch.
-- This updates ONE existing finance record. It does not create finance expenses,
-- alter received book costs, reserve stock or change batch lines.
create table if not exists private.web_batch_finance_amount_changes (
  id bigint generated always as identity primary key,
  batch_group_id uuid not null,
  finance_expense_id uuid not null,
  amount_before integer not null,
  amount_after integer not null,
  recorded_at timestamptz not null default now()
);
alter table private.web_batch_finance_amount_changes enable row level security;
revoke all on private.web_batch_finance_amount_changes from public, anon, authenticated;

create or replace function public.admin_web_batch_update_linked_expense(
  p_secret text, p_batch_group_id uuid, p_expense_id uuid,
  p_expected_amount integer, p_new_amount integer
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_old integer;
  v_category text;
  v_references integer;
begin
  if not coalesce(public.admin_verify(p_secret),false) then
    raise exception 'Admin tasdiqlanmadi';
  end if;
  if p_batch_group_id is null or p_expense_id is null then
    raise exception 'Partiya yoki xarajat topilmadi';
  end if;
  if p_new_amount is null or p_new_amount < 1 or p_new_amount > 1000000000 then
    raise exception 'Summa 1 va 1 milliard von oralig‘ida bo‘lishi kerak';
  end if;
  if p_expected_amount is null or p_expected_amount < 1 then
    raise exception 'Oldingi summa yaroqsiz, sahifani yangilang';
  end if;
  if not exists(select 1 from public.web_batch_finance_links l
      where l.batch_group_id=p_batch_group_id and l.finance_expense_id=p_expense_id) then
    raise exception 'Xarajat ushbu partiyaga biriktirilmagan';
  end if;
  select f.amount,f.category into v_old,v_category
    from public.finance_expenses f where f.id=p_expense_id for update;
  if not found then raise exception 'Moliyadagi xarajat topilmadi'; end if;
  if v_category not in ('inventory_purchase','transport') then
    raise exception 'Ushbu turdagi xarajatni partiyadan tahrirlab bo‘lmaydi';
  end if;
  select count(*) into v_references from public.web_batch_finance_links
    where finance_expense_id=p_expense_id;
  if v_references<>1 then
    raise exception 'Xarajat bir nechta partiyaga bog‘langan. Moliyada tekshiring';
  end if;
  if v_old<>p_expected_amount then
    raise exception 'Xarajat summasi boshqa joyda o‘zgartirilgan. Sahifani yangilang';
  end if;
  if v_old<>p_new_amount then
    update public.finance_expenses set amount=p_new_amount where id=p_expense_id;
    insert into private.web_batch_finance_amount_changes(
      batch_group_id,finance_expense_id,amount_before,amount_after)
    values(p_batch_group_id,p_expense_id,v_old,p_new_amount);
  end if;
  return jsonb_build_object('ok',true,'before',v_old,'after',p_new_amount);
end $$;
revoke all on function public.admin_web_batch_update_linked_expense(text,uuid,uuid,integer,integer)
  from public,anon,authenticated;
grant execute on function public.admin_web_batch_update_linked_expense(text,uuid,uuid,integer,integer)
  to anon,authenticated,service_role;
