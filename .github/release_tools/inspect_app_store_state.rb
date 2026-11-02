require_relative 'app_store_client'
apps = AppStoreClient.request(:get, '/v1/apps', query: { 'filter[bundleId]' => 'com.muhajeerbooks.app', 'limit' => 2 }).fetch('data')
abort 'Expected exactly one Muhajeer Books app' unless apps.length == 1
app_id = apps.first.fetch('id')
versions = AppStoreClient.request(:get, "/v1/apps/#{app_id}/appStoreVersions", query: { 'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState,releaseType' }).fetch('data')
builds = AppStoreClient.request(:get, '/v1/builds', query: { 'filter[app]' => app_id, 'sort' => '-uploadedDate', 'limit' => 5, 'include' => 'buildBetaDetail' })
evidence = {read_only: true, versions: versions, recent_builds: builds}
File.write("#{ENV.fetch('RUNNER_TEMP')}/app-store-state.json", JSON.pretty_generate(evidence))
versions.each { |v| puts v.fetch('attributes').inspect }
builds.fetch('data').each { |b| puts b.fetch('attributes').inspect }

# Read-only verification of the actual LIVE version's linked build.
released = versions.select { |v|
  v.dig('attributes','platform') == 'IOS' &&
  v.dig('attributes','appStoreState') == 'READY_FOR_SALE'
}
released.sort_by! { |v| v.dig('attributes','versionString').split('.').map(&:to_i) }
active = released.last
if active
  version = active.dig('attributes','versionString')
  build = AppStoreClient.request(:get, "/v1/appStoreVersions/#{active.fetch('id')}/build")
  number = build.dig('data', 'attributes', 'version')
  puts "PUBLIC_VERIFIED_VERSION=#{version}"
  puts "PUBLIC_VERIFIED_BUILD=#{number}"
end
