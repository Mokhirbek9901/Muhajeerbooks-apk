create or replace function private.finance_report_cash(p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report jsonb;
  v_total_revenue bigint := 0;
  v_cash_outflow bigint := 0;
  v_cash_result bigint := 0;
  v_cash_margin numeric := 0;
  v_operating_profit bigint := 0;
  v_operating_margin numeric := 0;
begin
  v_report := private.finance_report(p_period);
  v_total_revenue := coalesce((v_report->>'total_revenue')::bigint, 0);
  v_cash_outflow := coalesce((v_report->>'cash_outflow_total')::bigint, 0);
  v_operating_profit := coalesce((v_report->>'net_profit')::bigint, 0);
  v_operating_margin := coalesce((v_report->>'margin_percent')::numeric, 0);
  v_cash_result := v_total_revenue - v_cash_outflow;
  if v_total_revenue > 0 then
    v_cash_margin := round((v_cash_result::numeric / v_total_revenue::numeric) * 100, 1);
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

create or replace function public.admin_finance_report(p_secret text, p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  return private.finance_report_cash(p_period);
end;
$$;

create or replace function public.bot_finance_report(p_secret text, p_period text default 'month')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.bot_sales_list(p_secret, 1) limit 1;
  return private.finance_report_cash(p_period);
end;
$$;

revoke all on function private.finance_report_cash(text) from public, anon, authenticated;
grant execute on function public.admin_finance_report(text,text) to anon, authenticated;
grant execute on function public.bot_finance_report(text,text) to anon, authenticated;
