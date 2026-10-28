require_relative 'app_store_client'
apps = AppStoreClient.request(:get, '/v1/apps', query: { 'filter[bundleId]' => 'com.muhajeerbooks.app', 'limit' => 2 }).fetch('data')
abort 'Expected exactly one Muhajeer Books app' unless apps.length == 1
app_id = apps.first.fetch('id')
versions = AppStoreClient.request(:get, "/v1/apps/#{app_id}/appStoreVersions", query: { 'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState,releaseType' }).fetch('data')
states = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED READY_FOR_REVIEW METADATA_REJECTED WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE WAITING_FOR_EXPORT_COMPLIANCE]
versions.each do |version|
  next unless version.dig('attributes','platform') == 'IOS'
  state = version.dig('attributes','appStoreState')
  puts "iOS #{version.dig('attributes','versionString')}: #{state}, release=#{version.dig('attributes','releaseType')}"
  next unless states.include?(state)
  id = version.fetch('id')
  AppStoreClient.request(:patch, "/v1/appStoreVersions/#{id}", body: { data: { type: 'appStoreVersions', id: id, attributes: { releaseType: 'MANUAL' } } })
  checked = AppStoreClient.request(:get, "/v1/appStoreVersions/#{id}").fetch('data')
  abort 'Manual hold could not be verified' unless checked.dig('attributes','releaseType') == 'MANUAL'
  puts "VERIFIED MANUAL HOLD: #{checked.dig('attributes','versionString')}. Owner approval required."
end
