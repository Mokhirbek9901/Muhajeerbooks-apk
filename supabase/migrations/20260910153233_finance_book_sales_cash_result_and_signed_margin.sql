create or replace function private.finance_report_cash(p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report jsonb;
  v_books_revenue bigint := 0;
  v_cash_outflow bigint := 0;
  v_cash_result bigint := 0;
  v_cash_margin numeric := 0;
  v_operating_profit bigint := 0;
  v_operating_margin numeric := 0;
begin
  v_report := private.finance_report(p_period);

  v_books_revenue := coalesce((v_report->>'books_revenue')::bigint, 0);
  v_cash_outflow := coalesce((v_report->>'cash_outflow_total')::bigint, 0);
  v_cash_result := v_books_revenue - v_cash_outflow;
  v_operating_profit := coalesce((v_report->>'operating_profit')::bigint, 0);
  v_operating_margin := coalesce((v_report->>'operating_margin_percent')::numeric, (v_report->>'margin_percent')::numeric, 0);

  -- User-facing cash margin / ROI: remaining profit or loss versus money spent.
  -- Example: 100,000 expense and 17,000 book sales => -83,000 and -83.0%.
  if v_cash_outflow > 0 then
    v_cash_margin := round((v_cash_result::numeric / v_cash_outflow::numeric) * 100, 1);
  elsif v_books_revenue > 0 then
    v_cash_margin := 100.0;
  else
    v_cash_margin := 0.0;
  end if;

  return v_report || jsonb_build_object(
    'operating_profit', v_operating_profit,
    'operating_margin_percent', v_operating_margin,
    'cash_result', v_cash_result,
    'net_profit', v_cash_result,
    'margin_percent', v_cash_margin,
    'total_expenses', v_cash_outflow
  );
end;
$$;
