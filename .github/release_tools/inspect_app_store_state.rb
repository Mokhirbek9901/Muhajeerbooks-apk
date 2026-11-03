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

# Public versions, not TestFlight, are the sole source of forced-update versioning.
public_releases = versions.select { |v| v.dig('attributes','platform') == 'IOS' && v.dig('attributes','appStoreState') == 'READY_FOR_SALE' }
latest_public = public_releases.max_by { |v| v.dig('attributes','versionString').to_s.split('.').map(&:to_i) }
puts "PUBLIC_IOS_VERSION=#{latest_public&.dig('attributes','versionString')}"
