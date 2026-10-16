# frozen_string_literal: true
# Safe, read-only App Store Connect submission diagnostics.
require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

def token
  e = ->(v) { Base64.urlsafe_encode64(JSON.generate(v), padding: false) }
  now = Time.now.to_i
  header = { alg: 'ES256', kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID'), typ: 'JWT' }
  body = { iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID'),
           iat: now - 30, exp: now + 600, aud: 'appstoreconnect-v1' }
  input = [header, body].map { |v| e.call(v) }.join('.')
  key = OpenSSL::PKey.read(File.read(ENV.fetch('ASC_PRIVATE_KEY_PATH')))
  raw = OpenSSL::ASN1.decode(key.sign('SHA256', input))
  sig = raw.value.map { |i| i.value.to_s(2).rjust(32, "\x00") }.join
  "#{input}.#{Base64.urlsafe_encode64(sig, padding: false)}"
end

def request(method, path, query = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  uri.query = URI.encode_www_form(query) if query
  req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
  req['Authorization'] = "Bearer #{token}"
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) { |http| http.request(req) }
  obj = res.body.to_s.empty? ? {} : JSON.parse(res.body)
  unless res.is_a?(Net::HTTPSuccess)
    puts "ERR #{method} #{path}: #{res.code}, details=#{obj.fetch('errors',[]).map { |x| x.values_at('code','title','detail') }.inspect}"
    return {}
  end
  obj
end

app_id = ENV.fetch('ASC_APP_ID')
vers = request(:get, "/v1/apps/#{app_id}/appStoreVersions",
               { 'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState,appVersionState,build' }).fetch('data',[])
vers.each do |v|
  puts "App version #{v.dig('attributes','platform')} #{v.dig('attributes','versionString')}: #{v.dig('attributes','appStoreState')} id=#{v['id']}, build=#{v.dig('relationships','build','data','id')}"
  next unless v.dig('attributes','versionString') == '2.5.18'
  legacy = request(:get, "/v1/appStoreVersions/#{v['id']}/appStoreVersionSubmission")
  puts "Legacy submission relation=#{legacy.dig('data','id')} type=#{legacy.dig('data','type')}"
end
subs = request(:get, "/v1/apps/#{app_id}/reviewSubmissions", { 'limit' => 200, 'include' => 'appStoreVersionForReview' }).fetch('data',[])
puts "Found #{subs.length} review submissions"
subs.each do |v|
  puts "SUB #{v['id']} state=#{v.dig('attributes','state')}, platform=#{v.dig('attributes','platform')}, appStoreVersionForReview=#{v.dig('relationships','appStoreVersionForReview','data','id')}, submitted=#{v.dig('attributes','submittedDate')}"
  items=request(:get, "/v1/reviewSubmissions/#{v['id']}/items",{ 'limit' => 50 }).fetch('data',[])
  puts "  items=#{items.map { |i| [i['id'],i.dig('attributes','state'),i.dig('relationships','appStoreVersion','data','id')] }.inspect}"
end
