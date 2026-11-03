-- Server-only, safe App Store public version polling.
-- Uses Apple's public Korean storefront endpoint; never trusts client-supplied
-- version values and never downgrades the currently verified release.
CREATE TABLE IF NOT EXISTS private.ios_app_store_version_poll (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  request_id bigint,
  requested_at timestamptz,
  last_verified_version text,
  last_http_status integer,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.ios_app_store_version_poll ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.ios_app_store_version_poll FROM public,anon,authenticated;
INSERT INTO private.ios_app_store_version_poll(singleton) VALUES(true)
ON CONFLICT(singleton) DO NOTHING;

CREATE OR REPLACE FUNCTION private.poll_ios_published_app_store_version()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $fn$
DECLARE
  previous_request bigint;
  response_status integer;
  response_content text;
  document jsonb;
  found_version text;
  current_version text;
  next_request bigint;
BEGIN
  SELECT request_id INTO previous_request
    FROM private.ios_app_store_version_poll
   WHERE singleton=true FOR UPDATE;

  IF previous_request IS NOT NULL THEN
    SELECT status_code, content
      INTO response_status,response_content
      FROM net._http_response WHERE id=previous_request;
    UPDATE private.ios_app_store_version_poll
       SET last_http_status=response_status,updated_at=now()
     WHERE singleton=true;

    IF response_status=200 AND length(coalesce(response_content,'')) BETWEEN 1 AND 200000 THEN
      BEGIN
        document:=response_content::jsonb;
        found_version:=document #>> '{results,0,version}';
        IF (document->>'resultCount')::integer=1
          AND document #>> '{results,0,bundleId}'='com.muhajeerbooks.app'
          AND document #>> '{results,0,trackId}'='6817641775'
          AND found_version ~ '^[0-9]+([.][0-9]+){1,3}$' THEN

          SELECT value #>> '{}' INTO current_version
          FROM public.app_remote_config
          WHERE key='release.ios_published_version';

          IF current_version IS NULL
             OR current_version !~ '^[0-9]+([.][0-9]+){1,3}$'
             OR string_to_array(found_version,'.')::integer[] >
                string_to_array(current_version,'.')::integer[] THEN

            INSERT INTO public.app_remote_config(key,value,description,updated_at)
            VALUES
              ('release.ios_published_version',to_jsonb(found_version),
               'Verified Korean Apple public App Store listing',now()),
              ('release.ios_published_build','0'::jsonb,
               'New marketing version; public build not independently verified',now()),
              ('release.force_update_enabled','true'::jsonb,
               'Prompt for newly published iOS app updates',now())
            ON CONFLICT (key) DO UPDATE
              SET value=excluded.value,description=excluded.description,
                  updated_at=excluded.updated_at;
          END IF;

          UPDATE private.ios_app_store_version_poll
          SET last_verified_version=found_version,updated_at=now()
          WHERE singleton=true;
        END IF;
      EXCEPTION WHEN others THEN
        -- Malformed or temporary Apple data must never block app startup,
        -- clear the verified version, or alter live customer records.
        RAISE WARNING 'Apple public version response ignored: %',SQLSTATE;
      END;
    END IF;
  END IF;

  SELECT net.http_get(
    url := 'https://itunes.apple.com/lookup?id=6817641775&country=kr',
    headers := '{"Accept":"application/json","Cache-Control":"no-cache"}'::jsonb,
    timeout_milliseconds := 8000
  ) INTO next_request;
  UPDATE private.ios_app_store_version_poll
     SET request_id=next_request,requested_at=now(),updated_at=now()
   WHERE singleton=true;
END;
$fn$;

REVOKE ALL ON FUNCTION private.poll_ios_published_app_store_version()
FROM public,anon,authenticated;

SELECT cron.schedule(
  'muhajeer-ios-published-version-sync-15min',
  '*/15 * * * *',
  'SELECT private.poll_ios_published_app_store_version();'
); 
