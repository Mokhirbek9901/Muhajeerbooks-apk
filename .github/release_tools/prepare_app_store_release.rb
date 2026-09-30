require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

BUNDLE_ID = 'com.muhajeerbooks.app'
TARGET_VERSION = '2.5.16'
TARGET_BUILD = '1009'


def jwt_token
  encode = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
  now = Time.now.to_i
  header = {
    alg: 'ES256',
    kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID').strip,
    typ: 'JWT'
  }
  payload = {
    iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID').strip,
    iat: now - 30,
    exp: now + 600,
    aud: 'appstoreconnect-v1'
  }

  input = [header, payload].map { |part| encode.call(JSON.generate(part)) }.join('.')
  key_text = ENV.fetch('APP_STORE_CONNECT_PRIVATE_KEY').strip.gsub('\\n', "\n") + "\n"
  key = OpenSSL::PKey.read(key_text)
  sequence = OpenSSL::ASN1.decode(key.sign('SHA256', input))
  signature = sequence.value.map { |integer| integer.value.to_s(2).rjust(32, "\x00") }.join
  "#{input}.#{encode.call(signature)}"
end


def request(method, path, query: nil, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query) if query && !query.empty?

  klass = {
    get: Net::HTTP::Get,
    patch: Net::HTTP::Patch
  }.fetch(method)

  req = klass.new(uri)
  req['Authorization'] = "Bearer #{jwt_token}"
  req['Content-Type'] = 'application/json'
  req.body = JSON.generate(body) if body

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) do |http|
    http.request(req)
  end

  parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
  unless response.is_a?(Net::HTTPSuccess)
    details = parsed.fetch('errors', []).map do |e|
      [e['code'], e['title'], e['detail']].compact.join(': ')
    end.join('; ')
    abort "App Store Connect API #{method.to_s.upcase} #{path} failed (HTTP #{response.code}): #{details}"
  end
  parsed
end

apps = request(:get, '/v1/apps', query: {
  'filter[bundleId]' => BUNDLE_ID,
  'limit' => 2
}).fetch('data')
abort "Expected exactly one App Store app for #{BUNDLE_ID}; found #{apps.length}." unless apps.length == 1
app = apps.first
app_id = app.fetch('id')
puts "App: #{app.dig('attributes', 'name')} (#{app_id})"

versions = request(:get, "/v1/apps/#{app_id}/appStoreVersions", query: {
  'limit' => 50,
  'fields[appStoreVersions]' => 'platform,versionString,appStoreState,appVersionState,build'
}).fetch('data')

ios_versions = versions.select { |v| v.dig('attributes', 'platform') == 'IOS' }
version = ios_versions.find { |v| v.dig('attributes', 'versionString') == TARGET_VERSION }
version ||= ios_versions.find do |v|
  state = v.dig('attributes', 'appStoreState') || v.dig('attributes', 'appVersionState')
  %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED].include?(state)
end

abort 'No editable iOS App Store version was found.' unless version
version_id = version.fetch('id')
current_version = version.dig('attributes', 'versionString')
current_state = version.dig('attributes', 'appStoreState') || version.dig('attributes', 'appVersionState')
puts "Editable iOS version: #{current_version} (#{version_id}), state=#{current_state}"

if current_version != TARGET_VERSION
  updated = request(:patch, "/v1/appStoreVersions/#{version_id}", body: {
    data: {
      type: 'appStoreVersions',
      id: version_id,
      attributes: {
        versionString: TARGET_VERSION
      }
    }
  })
  actual = updated.dig('data', 'attributes', 'versionString')
  abort "Version update returned unexpected value #{actual.inspect}." unless actual == TARGET_VERSION
  puts "Updated App Store version: #{current_version} -> #{actual}"
else
  puts "App Store version is already #{TARGET_VERSION}."
end

builds = request(:get, '/v1/builds', query: {
  'filter[app]' => app_id,
  'filter[version]' => TARGET_BUILD,
  'include' => 'preReleaseVersion',
  'limit' => 20
})

build = builds.fetch('data').find do |item|
  release_id = item.dig('relationships', 'preReleaseVersion', 'data', 'id')
  release = builds.fetch('included', []).find do |r|
    r['type'] == 'preReleaseVersions' && r['id'] == release_id
  end
  release && release.dig('attributes', 'platform') == 'IOS' &&
    release.dig('attributes', 'version') == TARGET_VERSION
end

abort "Could not find iOS build #{TARGET_VERSION} (#{TARGET_BUILD})." unless build
build_id = build.fetch('id')
processing_state = build.dig('attributes', 'processingState')
abort "Build #{TARGET_BUILD} is not VALID (state=#{processing_state})." unless processing_state == 'VALID'
puts "Build found: #{TARGET_VERSION} (#{TARGET_BUILD}), id=#{build_id}, state=#{processing_state}"

request(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build", body: {
  data: {
    type: 'builds',
    id: build_id
  }
})
puts "Attached build #{TARGET_VERSION} (#{TARGET_BUILD}) to App Store version #{TARGET_VERSION}."

verified = request(:get, "/v1/appStoreVersions/#{version_id}", query: {
  'include' => 'build',
  'fields[appStoreVersions]' => 'platform,versionString,appStoreState,appVersionState,build',
  'fields[builds]' => 'version,processingState'
})
verified_version = verified.dig('data', 'attributes', 'versionString')
verified_build_id = verified.dig('data', 'relationships', 'build', 'data', 'id')
abort "Verification failed: version is #{verified_version.inspect}." unless verified_version == TARGET_VERSION
abort 'Verification failed: expected build is not attached.' unless verified_build_id == build_id
puts "VERIFIED: App Store version #{TARGET_VERSION} is linked to build #{TARGET_BUILD}."
