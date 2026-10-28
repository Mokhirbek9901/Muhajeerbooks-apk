require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module AppStoreClient
  module_function
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
    post: Net::HTTP::Post,
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


end
