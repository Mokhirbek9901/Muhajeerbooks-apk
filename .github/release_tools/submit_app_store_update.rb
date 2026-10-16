# frozen_string_literal: true
# Submits the latest processed iOS build as a new App Store update.
# Never changes an existing live version or modifies the Android release.
require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

BUNDLE_ID = 'com.muhajeerbooks.app'
TARGET_VERSION = ENV.fetch('IOS_MARKETING_VERSION')
TARGET_BUILD = ENV.fetch('IOS_BUILD_NUMBER')
APP_ID = ENV.fetch('ASC_APP_ID')

def jwt_token
  encode = ->(data) { Base64.urlsafe_encode64(data, padding: false) }
  now = Time.now.to_i
  header = { alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID'), typ: 'JWT' }
  claims = {
    iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID'),
    iat: now - 30, exp: now + 600, aud: 'appstoreconnect-v1'
  }
  input = [header, claims].map { |value| encode.call(JSON.generate(value)) }.join('.')
  key = OpenSSL::PKey.read(File.read(ENV.fetch('ASC_PRIVATE_KEY_PATH')))
  sequence = OpenSSL::ASN1.decode(key.sign('SHA256', input))
  signature = sequence.value.map { |n| n.value.to_s(2).rjust(32, "\x00") }.join
  "#{input}.#{encode.call(signature)}"
end

def asc(method, path, query: nil, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query) if query
  request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post,
                    patch: Net::HTTP::Patch }.fetch(method)
  req = request_class.new(uri)
  req['Authorization'] = "Bearer #{jwt_token}"
  req['Content-Type'] = 'application/json'
  req.body = JSON.generate(body) unless body.nil?
  result = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                           open_timeout: 30, read_timeout: 70) { |http| http.request(req) }
  json = result.body.to_s.empty? ? {} : JSON.parse(result.body)
  return json if result.is_a?(Net::HTTPSuccess)
  details = json.fetch('errors', []).map do |err|
    [err['code'], err['title'], err['detail']].compact.join(': ')
  end.join('; ')
  abort "App Store Connect #{method.to_s.upcase} #{path} (HTTP #{result.code}): #{details}"
end

versions = asc(:get, "/v1/apps/#{APP_ID}/appStoreVersions",
               query: { 'limit' => 100, 'fields[appStoreVersions]' =>
                 'platform,versionString,appStoreState,appVersionState,build' }).fetch('data')
versions.select! { |v| v.dig('attributes', 'platform') == 'IOS' }
puts "Existing iOS versions: #{versions.map { |v| v.dig('attributes', 'versionString') + ' (' + (v.dig('attributes','appStoreState') || '?') + ')' }.join(', ')}"
version = versions.find { |v| v.dig('attributes', 'versionString') == TARGET_VERSION }
unless version
  # Creating an update copies released-version metadata and screenshots.
  created = asc(:post, '/v1/appStoreVersions', body: {
    data: { type: 'appStoreVersions',
            attributes: { platform: 'IOS', versionString: TARGET_VERSION,
                          releaseType: 'AFTER_APPROVAL' },
            relationships: { app: { data: { type: 'apps', id: APP_ID } } } }
  })
  version = created.fetch('data')
  puts "Created App Store update #{TARGET_VERSION}."
end
version_id = version.fetch('id')
state = version.dig('attributes', 'appStoreState') ||
        version.dig('attributes', 'appVersionState')
abort "Version #{TARGET_VERSION} is not editable (#{state})" unless
  %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW].include?(state)
if %w[WAITING_FOR_REVIEW IN_REVIEW].include?(state)
  puts "Version #{TARGET_VERSION} already submitted for Apple review (#{state})."
  exit 0
end

builds = asc(:get, '/v1/builds', query: {
  'filter[app]' => APP_ID, 'filter[version]' => TARGET_BUILD,
  'include' => 'preReleaseVersion', 'limit' => 30
})
build = builds.fetch('data').find do |b|
  pre_id = b.dig('relationships', 'preReleaseVersion', 'data', 'id')
  pre = builds.fetch('included', []).find { |p| p['type'] == 'preReleaseVersions' && p['id'] == pre_id }
  pre && pre.dig('attributes', 'platform') == 'IOS' &&
    pre.dig('attributes', 'version') == TARGET_VERSION
end
abort "Build #{TARGET_VERSION} (#{TARGET_BUILD}) not found." unless build
abort "Build #{TARGET_BUILD} not VALID." unless build.dig('attributes', 'processingState') == 'VALID'
build_id = build.fetch('id')
asc(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build",
    body: { data: { type: 'builds', id: build_id } })
puts "Attached validated iOS build #{TARGET_BUILD} to version #{TARGET_VERSION}."

# An update needs release notes for the existing locales.
locales = asc(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
              query: { 'limit' => 50 }).fetch('data')
release_notes = "Muhajeer Books now offers improved book browsing and Instagram-ready images for the verified store owner. Customers can continue shopping and sharing book links."
locales.each do |loc|
  asc(:patch, "/v1/appStoreVersionLocalizations/#{loc.fetch('id')}",
      body: { data: { type: 'appStoreVersionLocalizations', id: loc.fetch('id'),
                     attributes: { whatsNew: release_notes } } })
end
puts "Updated release notes for #{locales.length} locale(s)."

review = asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions",
             query: { 'limit' => 50 }).fetch('data').find do |item|
  item.dig('attributes', 'state') == 'READY_FOR_REVIEW'
end
unless review
  review = asc(:post, '/v1/reviewSubmissions',
               body: { data: { type: 'reviewSubmissions',
                               relationships: { app: { data: { type: 'apps', id: APP_ID } } } } }).fetch('data')
end
review_id = review.fetch('id')
items = asc(:get, "/v1/reviewSubmissions/#{review_id}/items",
            query: { 'limit' => 50 }).fetch('data')
unless items.any? { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version_id }
  asc(:post, '/v1/reviewSubmissionItems',
      body: { data: { type: 'reviewSubmissionItems', relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: review_id } },
        appStoreVersion: { data: { type: 'appStoreVersions', id: version_id } }
      } } })
end
puts "Added app version #{TARGET_VERSION} to App Review submission."
result = asc(:patch, "/v1/reviewSubmissions/#{review_id}",
             body: { data: { type: 'reviewSubmissions', id: review_id,
                             attributes: { submitted: true } } })
puts "App Store update #{TARGET_VERSION} (#{TARGET_BUILD}) submitted: #{result.dig('data', 'attributes', 'state')}."
