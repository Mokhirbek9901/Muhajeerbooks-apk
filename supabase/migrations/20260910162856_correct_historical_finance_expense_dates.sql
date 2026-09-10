update public.finance_expenses
set expense_date = case
  when note = '29.08.2026 Andijon' then date '2026-08-29'
  when note = '30.08.2026 Sharxon' then date '2026-08-30'
  when note = '31.08.2026 Sharxon' then date '2026-08-31'
  when note = '2.09.2026 Sharxon' then date '2026-09-02'
  when note = '9.09.2026 Toshkent' then date '2026-09-09'
  when note = '2026-08 gacha qolgan kitoblar' then date '2026-09-10'
  else expense_date
end
where category = 'inventory_purchase'
  and source = 'admin'
  and note in (
    '29.08.2026 Andijon',
    '30.08.2026 Sharxon',
    '31.08.2026 Sharxon',
    '2.09.2026 Sharxon',
    '9.09.2026 Toshkent',
    '2026-08 gacha qolgan kitoblar'
  );
