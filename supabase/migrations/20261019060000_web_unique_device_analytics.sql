-- Web-only admin analytics: a phone-linked account is counted once per source.
-- Anonymous installation IDs must never be represented as physical devices
-- or as official Play/App Store downloads. No existing records are deleted.
create or replace function public.admin_web_unique_device_summary(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $fn$
declare result jsonb;
begin
  if not public._admin_secret_ok(p_secret) then
    raise exception 'Ruxsat yo‘q';
  end if;
  with eligible as (
    select
      case
        when lower(i.platform) in ('android_play','play_market','play_store') then 'play_market_or_test'
        when lower(i.platform) in ('ios_app_store','app_store') then 'app_store_or_testflight'
        when lower(i.platform) in ('ios','iphone') then 'ios_other'
        when lower(i.platform) = 'android' then 'android_apk'
        when lower(i.platform) = 'web' then 'web'
        else 'other'
      end as source,
      nullif(trim(i.phone_key),'') as phone_key,
      i.install_id
    from public.app_installations i
    where not exists (
      select 1 from public.analytics_excluded_installations e
      where e.install_id = i.install_id
    )
  ),
  per_source as (
    select source,
      count(*)::int as installation_ids,
      count(distinct phone_key)::int as linked_unique_phones,
      count(*) filter (where phone_key is null)::int as unlinked_installation_ids,
      (count(*) filter (where phone_key is not null) -
       count(distinct phone_key))::int as phone_linked_duplicate_ids
    from eligible group by source
  ),
  totals as (
    select
      count(*)::int as installation_ids,
      count(distinct phone_key)::int as linked_unique_phones,
      count(*) filter (where phone_key is null)::int as unlinked_installation_ids,
      (count(*) filter (where phone_key is not null) -
       count(distinct phone_key))::int as phone_linked_duplicate_ids
    from eligible
  )
  select jsonb_build_object(
    'source','app_installations; not store downloads',
    'total_installation_ids', t.installation_ids,
    'linked_unique_phones', t.linked_unique_phones,
    'unlinked_installation_ids',t.unlinked_installation_ids,
    'phone_linked_duplicate_ids',t.phone_linked_duplicate_ids,
    'platforms',coalesce(
      (select jsonb_object_agg(
        p.source,
        jsonb_build_object(
          'installation_ids', p.installation_ids,
          'linked_unique_phones', p.linked_unique_phones,
          'unlinked_installation_ids', p.unlinked_installation_ids,
          'phone_linked_duplicate_ids', p.phone_linked_duplicate_ids
        )
      ) from per_source p),
      '{}'::jsonb
    )
  ) into result
  from totals t;
  return result;
end;
$fn$;

revoke all on function public.admin_web_unique_device_summary(text)
 from public, anon, authenticated;
grant execute on function public.admin_web_unique_device_summary(text) to service_role;
