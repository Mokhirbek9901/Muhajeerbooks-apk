create or replace function public.customer_professional_code_verify(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select encode(
    extensions.digest(trim(coalesce(p_code, '')), 'sha256'),
    'hex'
  ) = '8454508fb369c047a533117c382daae3b1e5fef77d009881f4b9e9b90e353e93'
$$;

revoke execute on function public.customer_professional_code_verify(text)
  from public, anon, authenticated;
grant execute on function public.customer_professional_code_verify(text)
  to service_role;
