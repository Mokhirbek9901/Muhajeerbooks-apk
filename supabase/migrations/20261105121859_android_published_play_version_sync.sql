-- Release configuration only. No catalog, customer, order or finance writes.
create table if not exists private.android_play_version_poll (
  singleton boolean primary key default true check (singleton),
  request_id bigint,
  requested_at timestamptz,
  last_http_status integer,
  last_verified_build bigint,
  updated_at timestamptz not null default now()
);
alter table private.android_play_version_poll enable row level security;
revoke all on table private.android_play_version_poll from public, anon, authenticated;
insert into private.android_play_version_poll(singleton) values(true)
on conflict(singleton) do nothing;

create or replace function private.poll_android_published_play_version()
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  previous_request bigint;
  response_status integer;
  response_content text;
  document jsonb;
  found_build bigint;
  found_version text;
  current_build bigint;
  verified_at timestamptz;
  next_request bigint;
begin
  select request_id into previous_request from private.android_play_version_poll
    where singleton=true for update;
  if previous_request is not null then
    select status_code, content into response_status, response_content
      from net._http_response where id=previous_request;
    update private.android_play_version_poll
      set last_http_status=response_status, updated_at=now() where singleton=true;
    if response_status=200 and length(coalesce(response_content,'')) between 1 and 10000 then
      begin
        document:=response_content::jsonb;
        found_build:=(document->>'build')::bigint;
        found_version:=document->>'version';
        verified_at:=(document->>'verified_at')::timestamptz;
        select (value #>> '{}')::bigint into current_build from public.app_remote_config
          where key='release.android_published_build';
        if document->>'package'='com.muhajeerbooks.app'
          and document->>'track'='production'
          and document->>'lifecycle'='RELEASE_LIFECYCLE_STATE_PUBLISHED'
          and document->'available'='true'::jsonb
          and document->'full_rollout'='true'::jsonb
          and found_build between 1 and 2100000000
          and found_build>=coalesce(current_build,0)
          and found_version ~ '^[0-9]+([.][0-9]+){1,3}$'
          and verified_at between now()-interval '2 hours' and now()+interval '5 minutes'
        then
          insert into public.app_remote_config(key,value,description,updated_at) values
            ('release.android_published_version',to_jsonb(found_version),'Google-verified full public Production version',now()),
            ('release.android_published_build',to_jsonb(found_build),'Google-verified full public Production versionCode',now()),
            ('release.android_published_available','true'::jsonb,'Actual Google published lifecycle and full rollout confirmed',now())
          on conflict(key) do update set value=excluded.value,
            description=excluded.description, updated_at=excluded.updated_at;
          update private.android_play_version_poll set last_verified_build=found_build,
            updated_at=now() where singleton=true;
        end if;
      exception when others then
        raise warning 'Ignoring invalid public Play version metadata: %',sqlstate;
      end;
    end if;
  end if;
  select net.http_get(
    url:='https://raw.githubusercontent.com/Mokhirbek9901/Muhajeerbooks-apk/main/.github/published-android-release.json',
    headers:='{"Accept":"application/json","Cache-Control":"no-cache"}'::jsonb,
    timeout_milliseconds:=8000
  ) into next_request;
  update private.android_play_version_poll set request_id=next_request,
    requested_at=now(),updated_at=now() where singleton=true;
end;
$fn$;
revoke all on function private.poll_android_published_play_version() from public,anon,authenticated;
select cron.schedule('muhajeer-android-published-version-sync-15min',
  '*/15 * * * *','select private.poll_android_published_play_version();');
