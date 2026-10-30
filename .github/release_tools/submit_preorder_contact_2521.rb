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
abort 'Only owner-approved preorder-contact 2.5.21 may be submitted' unless TARGET_VERSION == '2.5.21' && TARGET_BUILD.match?(/^\d{4}$/) && APP_ID == '6817641775'

unless ENV['OWNER_APPROVED_PUBLIC_RELEASE'] == "#{TARGET_VERSION}(#{TARGET_BUILD})"
  abort 'Public review/release is blocked: the owner must test and approve this exact version/build first.'
end

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
                    patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }.fetch(method)
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

# Verify the *new* existing TestFlight build before touching any pending Apple review.
preflight = asc(:get, '/v1/builds', query: {
  'filter[app]' => APP_ID, 'filter[version]' => TARGET_BUILD,
  'include' => 'preReleaseVersion', 'limit' => 40
})
candidate = preflight.fetch('data').find do |b|
  p = preflight.fetch('included', []).find { |x| x['id'] == b.dig('relationships', 'preReleaseVersion', 'data', 'id') }
  p && p['type'] == 'preReleaseVersions' &&
    p.dig('attributes', 'platform') == 'IOS' &&
    p.dig('attributes', 'version') == TARGET_VERSION &&
    b.dig('attributes', 'processingState') == 'VALID'
end
abort '2.5.21 has not finished TestFlight validation; previous review left unchanged' unless candidate
puts "Verified processed 2.5.21 (#{TARGET_BUILD}) build before replacing pending review."

# Only supersede the known previous 2.5.20 App Review submission.
old = versions.find { |v| v.dig('attributes','versionString') == '2.5.20' }
if old && %w[WAITING_FOR_REVIEW IN_REVIEW].include?(old.dig('attributes','appStoreState'))
  submissions = asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions",
                    query: { 'limit' => 100, 'include' => 'appStoreVersionForReview' }).fetch('data')
  submission = submissions.find do |s|
    next false unless %w[WAITING_FOR_REVIEW IN_REVIEW].include?(s.dig('attributes','state'))
    attached = s.dig('relationships','appStoreVersionForReview','data','id')
    attached == old.fetch('id') ||
      asc(:get, "/v1/reviewSubmissions/#{s.fetch('id')}/items", query: { 'limit' => 50 }).fetch('data').any? do |item|
        item.dig('relationships','appStoreVersion','data','id') == old.fetch('id')
      end
  end
  abort 'Could not locate existing 2.5.20 review: no modifications made' unless submission
  asc(:patch, "/v1/reviewSubmissions/#{submission.fetch('id')}", body: {
    data: { type:'reviewSubmissions', id: submission.fetch('id'),
            attributes: { canceled: true } }
  })
  puts 'Superseded old 2.5.20 review only after newer processed build was verified.'
  limit = Time.now + 240
  loop do
    current = asc(:get, "/v1/appStoreVersions/#{old.fetch('id')}")
    state = current.dig('data','attributes','appStoreState')
    break unless %w[WAITING_FOR_REVIEW IN_REVIEW].include?(state)
    abort "Canceled older review but App Store version state is still #{state}" if Time.now > limit
    sleep 12
  end
end

version = versions.find { |v| v.dig('attributes', 'versionString') == TARGET_VERSION }
unless version
  # Only one unreleased iOS version is allowed. When the superseded version
  # remains as an editable draft, remove it after Apple's review cancellation.
  if old
    previous = asc(:get, "/v1/appStoreVersions/#{old.fetch('id')}")
    previous_state = previous.dig('data','attributes','appStoreState')
    if %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED READY_FOR_REVIEW].include?(previous_state)
      asc(:delete, "/v1/appStoreVersions/#{old.fetch('id')}")
      puts "Removed superseded 2.5.20 draft (#{previous_state}) to open 2.5.21 review."
    end
  end
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

# An App Store review version is immutable while in the review queue.
# Once the NEW build is validated, withdraw just this version's previous
# submission, reattach the fixed build and submit it afresh.
if %w[WAITING_FOR_REVIEW IN_REVIEW].include?(state)
  existing_build_id = version.dig('relationships', 'build', 'data', 'id')
  if existing_build_id == build_id
    puts "Latest build #{TARGET_BUILD} is already in App Review (#{state})."
    exit 0
  end
  submissions = asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions",
                    query: { 'limit' => 100, 'include' => 'appStoreVersionForReview' }).fetch('data')
  active = submissions.select do |submission|
    %w[WAITING_FOR_REVIEW IN_REVIEW].include?(submission.dig('attributes', 'state')) &&
      (submission.dig('attributes', 'platform').nil? ||
       submission.dig('attributes', 'platform') == 'IOS')
  end
  found = active.find do |submission|
    submission.dig('relationships', 'appStoreVersionForReview', 'data', 'id') == version_id
  end
  found ||= active.find do |submission|
    items = asc(:get, "/v1/reviewSubmissions/#{submission.fetch('id')}/items",
                query: { 'limit' => 50 }).fetch('data')
    items.any? { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version_id }
  end
  unless found
    puts "Active review submissions: #{active.map { |item| [item.fetch('id'), item.dig('relationships','appStoreVersionForReview','data','id')] }.inspect}"
    abort "Could not locate active App Review submission for #{TARGET_VERSION}"
  end
  puts "Removing outdated iOS build from review so build #{TARGET_BUILD} can replace it."
  asc(:patch, "/v1/reviewSubmissions/#{found.fetch('id')}",
      body: { data: { type: 'reviewSubmissions', id: found.fetch('id'),
                      attributes: { canceled: true } } })
  deadline = Time.now + 240
  loop do
    current = asc(:get, "/v1/appStoreVersions/#{version_id}",
                  query: { 'fields[appStoreVersions]' =>
                    'platform,versionString,appStoreState,appVersionState,build' })
    state = current.dig('data', 'attributes', 'appStoreState') ||
            current.dig('data', 'attributes', 'appVersionState')
    break if %w[DEVELOPER_REJECTED PREPARE_FOR_SUBMISSION READY_FOR_REVIEW REJECTED].include?(state)
    abort "Cannot replace in-review version; current state #{state}" if Time.now >= deadline
    sleep 12
  end
  puts "Previous review submission canceled; version is now #{state}."
end

asc(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build",
    body: { data: { type: 'builds', id: build_id } })
puts "Attached validated iOS build #{TARGET_BUILD} to version #{TARGET_VERSION}."

# Public rollout starts only after Apple finishes App Review.
asc(:patch, "/v1/appStoreVersions/#{version_id}",
    body: { data: { type: 'appStoreVersions', id: version_id,
                    attributes: { releaseType: 'AFTER_APPROVAL' } } })
puts "Approved public release policy: AFTER_APPROVAL (not before review)."


# An update needs release notes for the existing locales.
locales = asc(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
              query: { 'limit' => 50 }).fetch('data')
release_notes = "Choose Instagram or Telegram for prepaid book orders and receive a message at the username you provide. Follow preorder status under Profile > Preorders. Improved order packing, reliability and stability."
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
verified=asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions",query: { 'limit' => 100 }).fetch('data').find{|v|v.fetch('id')==review_id}
abort 'Apple review submission did not persist' unless verified && %w[WAITING_FOR_REVIEW IN_REVIEW READY_FOR_REVIEW].include?(verified.dig('attributes','state'))
puts "VERIFIED_APPSTORE_SUBMISSION version=#{TARGET_VERSION} build=#{TARGET_BUILD} review_state=#{verified.dig('attributes','state')} review_id=#{review_id}"

