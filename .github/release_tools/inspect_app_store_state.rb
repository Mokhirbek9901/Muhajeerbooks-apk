require_relative 'app_store_client'
apps = AppStoreClient.request(:get, '/v1/apps', query: { 'filter[bundleId]' => 'com.muhajeerbooks.app', 'limit' => 2 }).fetch('data')
abort 'Expected exactly one Muhajeer Books app' unless apps.length == 1
app_id = apps.first.fetch('id')
versions = AppStoreClient.request(:get, "/v1/apps/#{app_id}/appStoreVersions", query: { 'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState,releaseType,build' }).fetch('data')
builds = AppStoreClient.request(:get, '/v1/builds', query: { 'filter[app]' => app_id, 'sort' => '-uploadedDate', 'limit' => 5, 'include' => 'buildBetaDetail' })
evidence = {read_only: true, versions: versions, recent_builds: builds}
File.write("#{ENV.fetch('RUNNER_TEMP')}/app-store-state.json", JSON.pretty_generate(evidence))
versions.each { |v| puts "APP_STORE_VERSION #{v.dig('attributes','versionString')} state=#{v.dig('attributes','appStoreState')} release=#{v.dig('attributes','releaseType')} build_id=#{v.dig('relationships','build','data','id')}" }
builds.fetch('data').each { |b| puts b.fetch('attributes').inspect }

# Read-only pre-release audit (book-detail restoration candidate, 2026-11-03).
