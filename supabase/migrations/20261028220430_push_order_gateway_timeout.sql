-- Give the async order gateway time to wake Railway and contact push providers.
-- Preserve the bot timeout, trigger behavior, ownership and existing grants.
do $migration$
declare
  definition text := pg_get_functiondef('private.notify_app_order_push()'::regprocedure);
  pattern text := $pattern$(headers := jsonb_build_object\('Content-Type','application/json','X-Muhajeer-Push-Secret',v_secret\),[[:space:]]*timeout_milliseconds := )5000$pattern$;
  matches integer;
begin
  select count(*) into matches from regexp_matches(definition, pattern, 'g');
  if matches <> 2 then
    raise exception 'Expected exactly two order push HTTP timeouts; found %', matches;
  end if;
  execute regexp_replace(definition, pattern, E'\\160000', 'g');
end
$migration$;
