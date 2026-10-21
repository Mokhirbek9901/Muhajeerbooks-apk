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
        when :patch then Net::HTTP::Patch.new(uri)
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

apps = request(:get, '/v1/apps', query: { 'filter[bundleId]' => BUNDLE_ID, 'limit' => 2 }).fetch('data')
abort 'Expected one app.' unless apps.length == 1
app_id = apps.first.fetch('id')
response = request(:get, '/v1/builds', query: { 'filter[app]' => app_id, 'sort' => '-uploadedDate', 'limit' => 20, 'include' => 'buildBetaDetail,preReleaseVersion' })
builds = response.fetch('data')
included = response.fetch('included', [])
build_numbers = builds.to_h { |b| [b.fetch('id'), b.dig('attributes', 'version')] }
builds.first(12).each do |build|
  id = build.fetch('id')
  beta_id = build.dig('relationships', 'buildBetaDetail', 'data', 'id')
  beta = included.find { |item| item['type'] == 'buildBetaDetails' && item['id'] == beta_id }
  release_id = build.dig('relationships', 'preReleaseVersion', 'data', 'id')
  release = included.find { |item| item['type'] == 'preReleaseVersions' && item['id'] == release_id }
  testers = request(:get, "/v1/builds/#{id}/individualTesters", query: { 'limit' => 200 }).fetch('data')
  puts JSON.generate({ kind: 'build', id: id, number: build.dig('attributes','version'), version: release&.dig('attributes','version'), processing: build.dig('attributes','processingState'), expired: build.dig('attributes','expired'), minimum_os: build.dig('attributes','minOsVersion'), beta: beta&.fetch('attributes'), individual_testers: testers.length })
end
groups = request(:get, "/v1/apps/#{app_id}/betaGroups", query: { 'limit' => 200 }).fetch('data')
groups.each do |group|
  id = group.fetch('id')
  links = request(:get, "/v1/betaGroups/#{id}/relationships/builds", query: { 'limit' => 200 }).fetch('data')
  testers = request(:get, "/v1/betaGroups/#{id}/betaTesters", query: { 'limit' => 200 }).fetch('data')
  puts JSON.generate({ kind: 'group', id: id, name: group.dig('attributes','name'), internal: group.dig('attributes','isInternalGroup'), automatic: group.dig('attributes','hasAccessToAllBuilds'), public_link: group.dig('attributes','publicLinkEnabled'), testers: testers.length, builds: links.map { |item| build_numbers[item['id']] || item['id'] } })
end
