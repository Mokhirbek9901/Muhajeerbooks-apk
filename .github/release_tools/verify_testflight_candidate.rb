require_relative 'app_store_client'
app_id = ENV.fetch('ASC_APP_ID')
build_id = ENV.fetch('ASC_BUILD_ID')
deadline = Time.now + 300
assigned = false
loop do
  detail = AppStoreClient.request(:get, "/v1/builds/#{build_id}/buildBetaDetail").fetch('data')
  state = detail.dig('attributes', 'internalBuildState')
  groups = AppStoreClient.request(:get, "/v1/apps/#{app_id}/betaGroups", query: { 'limit' => 200 }).fetch('data')
  internal = groups.select { |g| g.dig('attributes','isInternalGroup') == true }
  puts "Exact TestFlight candidate #{ENV.fetch('IOS_BUILD_NUMBER')}: internal=#{state}, existing_internal_groups=#{internal.length}"
  puts "Beta detail: #{detail.fetch('attributes',{}).inspect}"
  if state == 'IN_BETA_TESTING'
    abort 'No existing internal tester group is available' if internal.empty?
    break
  end
  abort 'No existing internal TestFlight tester group was found; no tester was added or invited.' if internal.empty?
  unless assigned
    internal.each do |group|
      AppStoreClient.request(:post, "/v1/betaGroups/#{group.fetch('id')}/relationships/builds", body: { data: [{ type: 'builds', id: build_id }] })
    end
    assigned = true
    puts 'Attached this build to the existing internal groups only; no tester was added or invited.'
  end
  abort 'Apple has not yet made the exact build available for internal testing' if Time.now >= deadline
  sleep 15
end
puts 'VERIFIED exact candidate is available for the existing internal TestFlight group. No public release or external invitation.'
