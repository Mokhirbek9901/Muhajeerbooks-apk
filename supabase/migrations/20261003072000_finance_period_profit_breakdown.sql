-- Add period-scoped expense category totals to the admin finance report.
-- Existing finance formulas are preserved; these fields are additive only.

create or replace function public.admin_finance_report(
  p_secret text,
  p_period text default 'month'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report jsonb;
  v_start_date date;
  v_end_date date;
  v_packaging bigint := 0;
  v_ads bigint := 0;
  v_transport bigint := 0;
  v_other bigint := 0;
  v_manual_postage bigint := 0;
  v_inventory_purchase bigint := 0;
  v_profit_cost_total bigint := 0;
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;

  v_report := private.finance_report_cash(p_period);

  begin
    v_start_date := nullif(v_report->>'period_start', '')::date;
  exception when others then
    v_start_date := null;
  end;

  begin
    v_end_date := nullif(v_report->>'period_end', '')::date;
  exception when others then
    v_end_date := null;
  end;

  select
    coalesce(sum(e.amount) filter (where e.category = 'packaging'), 0),
    coalesce(sum(e.amount) filter (where e.category = 'ads'), 0),
    coalesce(sum(e.amount) filter (where e.category = 'transport'), 0),
    coalesce(sum(e.amount) filter (where e.category = 'other'), 0),
    coalesce(sum(e.amount) filter (where e.category = 'postage'), 0),
    coalesce(sum(e.amount) filter (where e.category = 'inventory_purchase'), 0)
  into
    v_packaging,
    v_ads,
    v_transport,
    v_other,
    v_manual_postage,
    v_inventory_purchase
  from public.finance_expenses e
  where (v_start_date is null or e.expense_date >= v_start_date)
    and (v_end_date is null or e.expense_date <= v_end_date);

  v_profit_cost_total :=
    coalesce((v_report->>'cost_of_goods')::bigint, 0)
    + coalesce((v_report->>'store_postage_expense')::bigint, 0)
    + coalesce((v_report->>'other_expenses')::bigint, 0);

  return v_report || jsonb_build_object(
    'expense_breakdown',
    jsonb_build_object(
      'packaging', v_packaging,
      'ads', v_ads,
      'transport', v_transport,
      'other', v_other,
      'manual_postage', v_manual_postage,
      'inventory_purchase', v_inventory_purchase
    ),
    'profit_cost_total', v_profit_cost_total
  );
end;
$$;

grant execute on function public.admin_finance_report(text,text)
to anon, authenticated;
