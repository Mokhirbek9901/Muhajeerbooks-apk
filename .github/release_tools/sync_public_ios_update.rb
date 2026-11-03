# frozen_string_literal: true
# Sync ONLY a publicly released iOS marketing version into the read-only
# customer app config. Draft/TestFlight/review versions are never eligible.
# Run from the scheduled GitHub Actions workflow. No native release is created.
require 'json'
require 'net/http'
require 'uri'
require_relative 'app_store_client'

BUNDLE_ID = 'com.muhajeerbooks.app'
SUPABASE_URL = 'https://rytfhjvhjxnbhgitowho.supabase.co'

def comparable(version)
  unless version.is_a?(String) && version.match?(/\A\d+(?:\.\d+){1,3}\z/)
    abort 'Unexpected App Store version format'
  end
  version.split('.').map(&:to_i)
end

def supabase_request(method, path, data = nil)
  role_key = ENV.fetch('SUPABASE_SERVICE_ROLE_KEY')
  abort 'Missing service-role credential' if role_key.strip.empty?
  uri = URI(SUPABASE_URL + path)
  req = case method
        when :get then Net::HTTP::Get.new(uri)
        when :post then Net::HTTP::Post.new(uri)
        else abort 'Method not permitted'
        end
  req['apikey'] = role_key
  req['Authorization'] = "Bearer #{role_key}"
  req['Content-Type'] = 'application/json'
  req['Prefer'] = 'resolution=merge-duplicates,return=minimal' if method == :post
  req.body = JSON.generate(data) if data
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                             open_timeout: 15, read_timeout: 30) { |http| http.request(req) }
  abort "Supabase remote config HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  response.body.to_s.empty? ? nil : JSON.parse(response.body)
end

apps = AppStoreClient.request(:get, '/v1/apps',
  query: {'filter[bundleId]' => BUNDLE_ID, 'limit' => 2}).fetch('data')
abort 'Ambiguous App Store app' unless apps.length == 1
app_id = apps.first.fetch('id')
versions = AppStoreClient.request(:get, "/v1/apps/#{app_id}/appStoreVersions",
  query: {'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState'}).fetch('data')
public = versions.select do |v|
  a = v.fetch('attributes')
  a['platform'] == 'IOS' && a['appStoreState'] == 'READY_FOR_SALE'
end
abort 'Apple returned no published iOS release; keep existing config' if public.empty?
published = public.max_by { |v| comparable(v.dig('attributes', 'versionString')) }
published_version = published.dig('attributes', 'versionString')

rows = supabase_request(:get, '/rest/v1/app_remote_config?select=key,value&key=in.(release.ios_published_version,release.ios_published_build,release.force_update_enabled)')
abort 'Published-version config missing' unless rows.is_a?(Array)
existing = rows.to_h { |row| [row.fetch('key'), row.fetch('value')] }
current = existing.fetch('release.ios_published_version', '')
if !current.to_s.empty? && comparable(published_version) <= comparable(current.to_s)
  puts "Verified: App Store public #{published_version}; server #{current}. No change."
  exit 0
end

# The previous marketing version's build number does NOT apply to a new
# marketing version. Never wrongly force a same-version reinstall.
data = [
  {'key'=>'release.ios_published_version', 'value'=>published_version,
   'description'=>'Only Apple public READY_FOR_SALE marketing version'},
  {'key'=>'release.ios_published_build', 'value'=>0,
   'description'=>'Do not force same marketing version without verified public build'},
  {'key'=>'release.force_update_enabled', 'value'=>true,
   'description'=>'Prompt old installations to update after public release'}
]
supabase_request(:post, '/rest/v1/app_remote_config?on_conflict=key', data)
confirmed = supabase_request(:get, '/rest/v1/app_remote_config?select=key,value&key=eq.release.ios_published_version')
abort 'Published version not persisted' unless confirmed.is_a?(Array) && confirmed.one? &&
  confirmed.first['value'] == published_version
puts "Synced App Store public #{published_version} to customer config. No app release changed."
