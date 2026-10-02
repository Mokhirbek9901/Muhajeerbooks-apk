require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'
STDOUT.sync = true

BUNDLE_ID = 'com.muhajeerbooks.app'

def jwt_token
  enc = ->(v) { Base64.urlsafe_encode64(v, padding: false) }
  now = Time.now.to_i
  header = { alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID').strip, typ: 'JWT' }
  payload = { iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID').strip, iat: now - 30, exp: now + 600, aud: 'appstoreconnect-v1' }
  input = [header, payload].map { |p| enc.call(JSON.generate(p)) }.join('.')
  key = OpenSSL::PKey.read(File.read(ENV.fetch('ASC_PRIVATE_KEY_PATH')))
  seq = OpenSSL::ASN1.decode(key.sign('SHA256', input))
  raw = seq.value.map { |integer| integer.value.to_s(2).rjust(32, "\x00") }.join
  "#{input}.#{enc.call(raw)}"
end

def request(method, path, query: nil, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query) if query && !query.empty?
  req = case method
        when :get then Net::HTTP::Get.new(uri)
        when :post then Net::HTTP::Post.new(uri)
        else raise "Unsupported method #{method}"
        end
  req['Authorization'] = "Bearer #{jwt_token}"
  if body
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(body)
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) { |h| h.request(req) }
  return {} if res.code.to_i == 204
  parsed = JSON.parse(res.body.empty? ? '{}' : res.body)
  unless res.code.to_i.between?(200, 299)
    details = parsed.fetch('errors', []).map { |e| [e['code'], e['title'], e['detail']].compact.join(': ') }.join(' | ')
    abort "#{method.to_s.upcase} #{path} failed HTTP #{res.code}: #{details}"
  end
  parsed
end

def build_for(app_id, build_number)
  rows = request(:get, '/v1/builds',
    query: { 'filter[app]' => app_id, 'filter[version]' => build_number, 'limit' => 10 }).fetch('data')
  abort "Build #{build_number} not found." if rows.empty?
  rows.first
end

source_number = ENV.fetch('SOURCE_BUILD', '1009')
target_number = ENV.fetch('TARGET_BUILD', '1014')

apps = request(:get, '/v1/apps', query: { 'filter[bundleId]' => BUNDLE_ID, 'limit' => 2 }).fetch('data')
abort "Expected exactly one app for #{BUNDLE_ID}, found #{apps.length}." unless apps.length == 1
app_id = apps.first.fetch('id')

source = build_for(app_id, source_number)
target = build_for(app_id, target_number)
source_id = source.fetch('id')
target_id = target.fetch('id')

groups = request(:get, '/v1/betaGroups',
  query: { 'filter[builds]' => source_id, 'limit' => 200 }).fetch('data')
testers = request(:get, "/v1/builds/#{source_id}/individualTesters", query: { 'limit' => 200 }).fetch('data')

puts "Source build #{source_number}: #{groups.length} beta group(s), #{testers.length} individual tester(s)."
abort "Build #{source_number} has no TestFlight groups or individual testers to copy." if groups.empty? && testers.empty?

unless groups.empty?
  request(:post, "/v1/builds/#{target_id}/relationships/betaGroups",
    body: { data: groups.map { |g| { type: 'betaGroups', id: g.fetch('id') } } })
  puts "Copied #{groups.length} beta group(s) to build #{target_number}."
end

unless testers.empty?
  request(:post, "/v1/builds/#{target_id}/relationships/individualTesters",
    body: { data: testers.map { |t| { type: 'betaTesters', id: t.fetch('id') } } })
  puts "Copied #{testers.length} individual tester(s) to build #{target_number}."
end

target_groups = request(:get, '/v1/betaGroups',
  query: { 'filter[builds]' => target_id, 'limit' => 200 }).fetch('data')
target_testers = request(:get, "/v1/builds/#{target_id}/individualTesters", query: { 'limit' => 200 }).fetch('data')

missing_groups = groups.map { |x| x['id'] } - target_groups.map { |x| x['id'] }
missing_testers = testers.map { |x| x['id'] } - target_testers.map { |x| x['id'] }
abort "Verification failed. Missing groups=#{missing_groups.inspect}, testers=#{missing_testers.inspect}" unless missing_groups.empty? && missing_testers.empty?

puts "SUCCESS: TestFlight access copied from #{source_number} to #{target_number}."
