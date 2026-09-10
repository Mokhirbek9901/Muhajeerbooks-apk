-- Add publisher metadata without changing existing books or admin access checks.
alter table public.books add column if not exists publisher text not null default '';

do $migration$
declare
  original text;
  patched text;
begin
  select pg_get_functiondef('public.admin_save_book(text,uuid,jsonb)'::regprocedure) into original;
  if position('publisher' in original) = 0 then
    patched := replace(original,
      'public.books(title,author,category,',
      'public.books(title,author,publisher,category,');
    patched := replace(patched,
      $old$coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),$old$,
      $new$coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),
      btrim(regexp_replace(coalesce(p_data->>'publisher',''), '\s+', ' ', 'g')),$new$);
    -- The previous replacement also matches the UPDATE author expression.
    -- Replace that inserted expression with an assignment preserving older clients.
    patched := replace(patched,
      $old$author=coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),
      btrim(regexp_replace(coalesce(p_data->>'publisher',''), '\s+', ' ', 'g')),$old$,
      $new$author=coalesce(nullif(trim(p_data->>'author'),''),'Ko‘rsatilmagan'),
      publisher=case when p_data ? 'publisher' then
        btrim(regexp_replace(coalesce(p_data->>'publisher',''), '\s+', ' ', 'g'))
        else publisher end,$new$);
    if patched = original or position('publisher=case' in patched) = 0
       or position('author,publisher,category' in patched) = 0 then
      raise exception 'Unexpected admin_save_book definition; publisher change aborted';
    end if;
    execute patched;
  end if;
end;
$migration$;
notify pgrst, 'reload schema';
