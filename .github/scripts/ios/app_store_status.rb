require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'
STDOUT.sync = true

def token
  encode = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
  now = Time.now.to_i
  header = { alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID').strip, typ: 'JWT' }
  payload = { iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID').strip, iat: now - 30,
              exp: now + 600, aud: 'appstoreconnect-v1' }
  input = [header, payload].map { |part| encode.call(JSON.generate(part)) }.join('.')
  key = OpenSSL::PKey.read(File.read(ENV.fetch('ASC_PRIVATE_KEY_PATH')))
  sequence = OpenSSL::ASN1.decode(key.sign('SHA256', input))
  signature = sequence.value.map { |integer| integer.value.to_s(2).rjust(32, "\x00") }.join
  "#{input}.#{encode.call(signature)}"
end

def get(path, query)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query)
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{token}"
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) do |http|
    http.request(request)
  end
  data = JSON.parse(response.body)
  unless response.is_a?(Net::HTTPSuccess)
    codes = data.fetch('errors', []).map { |e| "#{e['code']}: #{e['title']}" }.join('; ')
    abort "App Store Connect API HTTP #{response.code}: #{codes}"
  end
  data
end

if ARGV.fetch(0) == 'preflight'
  apps = get('/v1/apps', { 'filter[bundleId]' => 'com.muhajeerbooks.app', 'limit' => 2 }).fetch('data')
  abort 'App Store Connect has no accessible app record for com.muhajeerbooks.app. Create/authorize that app record before uploading.' unless apps.length == 1
  app = apps.first
  File.open(ENV.fetch('GITHUB_ENV'), 'a') { |f| f.puts("ASC_APP_ID=#{app.fetch('id')}") }
  puts "App Store Connect API authenticated; app #{app.fetch('attributes').fetch('name')} (#{app.fetch('id')}) found."
else
  deadline = Time.now + 1200
  loop do
    builds = get('/v1/builds', { 'filter[app]' => ENV.fetch('ASC_APP_ID'),
                              'filter[version]' => ENV.fetch('IOS_BUILD_NUMBER'), 'limit' => 10,
                              'include' => 'preReleaseVersion' })
    build = builds.fetch('data').find do |item|
      release_id = item.dig('relationships', 'preReleaseVersion', 'data', 'id')
      release = builds.fetch('included', []).find { |r| r['id'] == release_id && r['type'] == 'preReleaseVersions' }
      release && release.dig('attributes', 'platform') == 'IOS' &&
        release.dig('attributes', 'version') == ENV.fetch('IOS_MARKETING_VERSION')
    end
    if build
      attributes = build.fetch('attributes')
      state = attributes.fetch('processingState')
      puts "App Store Connect build #{attributes.fetch('version')} (#{build.fetch('id')}): #{state}"
      if state == 'VALID'
        result = { app_id: ENV.fetch('ASC_APP_ID'), build_id: build.fetch('id'),
                   version: ENV.fetch('IOS_MARKETING_VERSION'), build_number: attributes.fetch('version'),
                   processing_state: state, uploaded_date: attributes['uploadedDate'],
                   uses_non_exempt_encryption: attributes['usesNonExemptEncryption'] }
        File.write("#{ENV.fetch('RUNNER_TEMP')}/testflight-result.json", JSON.pretty_generate(result) + "\n")
        File.open(ENV.fetch('GITHUB_STEP_SUMMARY'), 'a') do |f|
          f.puts("TestFlight upload accepted and Apple processing VALID: #{result[:version]} (#{result[:build_number]}), build #{result[:build_id]}.")
        end
        break
      end
      abort "Apple processing rejected the uploaded build: #{state}" if %w[FAILED INVALID].include?(state)
    else
      puts 'Upload finished; waiting for the build to appear in App Store Connect.'
    end
    abort 'Upload finished, but Apple processing has not reached VALID within 20 minutes. Check this uploaded build before retrying.' if Time.now >= deadline
    sleep 30
  end
end
