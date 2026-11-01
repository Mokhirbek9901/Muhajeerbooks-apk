-- Restore direct app RPC access; public.admin_verify(p_secret) still checks
-- the admin secret before any mutation. No data is modified.
grant execute on function public.admin_web_batch_apply_edits(text,text,text,jsonb,jsonb)
  to anon, authenticated;
do $verify$
begin
  if not has_function_privilege('anon',
    'public.admin_web_batch_apply_edits(text,text,text,jsonb,jsonb)'::regprocedure,
    'EXECUTE')
  then raise exception 'The web batch editor must remain callable by the app'; end if;
end $verify$;