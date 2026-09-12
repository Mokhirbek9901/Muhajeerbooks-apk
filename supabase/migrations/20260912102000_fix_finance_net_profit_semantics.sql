create or replace function private.finance_report_cash(p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report jsonb;
  v_books_revenue bigint := 0;
  v_cost_of_goods bigint := 0;
  v_inventory_purchases bigint := 0;
  v_store_postage bigint := 0;
  v_other_expenses bigint := 0;
  v_operating_profit bigint := 0;
  v_operating_margin numeric := 0;
  v_profit_expenses bigint := 0;
  v_cash_spent bigint := 0;
  v_cash_flow_result bigint := 0;
begin
  v_report := private.finance_report(p_period);

  v_books_revenue := coalesce((v_report->>'books_revenue')::bigint, 0);
  v_cost_of_goods := coalesce((v_report->>'cost_of_goods')::bigint, 0);
  v_inventory_purchases := coalesce((v_report->>'inventory_purchases')::bigint, 0);
  v_store_postage := coalesce((v_report->>'store_postage_expense')::bigint, 0);
  v_other_expenses := coalesce((v_report->>'other_expenses')::bigint, 0);
  v_operating_profit := coalesce((v_report->>'operating_profit')::bigint, 0);
  v_operating_margin := coalesce((v_report->>'operating_margin_percent')::numeric, 0);

  -- Sof foyda faqat sotilgan tovar tannarxi va shu davr operatsion xarajatlarini hisoblaydi.
  -- Yangi partiya xaridi alohida pul oqimi bo'lib qoladi; u sotilmaguncha foydani kamaytirmaydi.
  v_profit_expenses := v_cost_of_goods + v_store_postage + v_other_expenses;
  v_cash_spent := v_inventory_purchases + v_store_postage + v_other_expenses;
  v_cash_flow_result := v_books_revenue - v_cash_spent;

  return v_report || jsonb_build_object(
    'net_profit', v_operating_profit,
    'cash_result', v_operating_profit,
    'margin_percent', v_operating_margin,
    'total_expenses', v_profit_expenses,
    'cash_outflow_total', v_profit_expenses,
    'cash_flow_result', v_cash_flow_result,
    'cash_spent_total', v_cash_spent
  );
end;
$$;
