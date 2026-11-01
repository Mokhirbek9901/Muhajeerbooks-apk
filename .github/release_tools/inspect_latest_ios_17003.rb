# frozen_string_literal: true
require_relative 'app_store_client'
require 'json'

app_id='6817641775'
apps=AppStoreClient.request(:get,'/v1/apps',query:{'filter[bundleId]'=>'com.muhajeerbooks.app','limit'=>2}).fetch('data')
abort 'Unexpected app identity' unless apps.length==1 && apps.first['id']==app_id
versions=AppStoreClient.request(:get,"/v1/apps/#{app_id}/appStoreVersions",
  query:{'limit'=>100,'fields[appStoreVersions]'=>'platform,versionString,appStoreState,releaseType'}).fetch('data')
ios=versions.select{|v|v.dig('attributes','platform')=='IOS'}.map do |v|
  rel=AppStoreClient.request(:get,"/v1/appStoreVersions/#{v['id']}/relationships/build")['data']
  {id:v['id'],version:v.dig('attributes','versionString'),state:v.dig('attributes','appStoreState'),
   attached_build_id:rel&&rel['id']}
end
builds=AppStoreClient.request(:get,'/v1/builds',query:{
 'filter[app]'=>app_id,'include'=>'preReleaseVersion','sort'=>'-uploadedDate','limit'=>50
})
pres=builds.fetch('included',[])
mapped=builds.fetch('data').map do |b|
  rel=b.dig('relationships','preReleaseVersion','data','id')
  pre=pres.find{|i|i['id']==rel}
  {id:b['id'],build:b.dig('attributes','version'),state:b.dig('attributes','processingState'),
    uploaded:b.dig('attributes','uploadedDate'),platform:pre&.dig('attributes','platform'),
    version:pre&.dig('attributes','version')}
end.select{|b|b[:platform]=='IOS'}.first(20)
subs=AppStoreClient.request(:get,"/v1/apps/#{app_id}/reviewSubmissions",
 query:{'limit'=>100}).fetch('data').map{|r|{id:r['id'],state:r.dig('attributes','state')}}
puts 'RELEASE_STATE '+JSON.generate({versions:ios,builds:mapped,submissions:subs})
candidate=mapped.find{|x|x[:version]=='2.5.23'&&x[:build]=='17003'}
abort 'Required 2.5.23 (17003) does not exist as VALID TestFlight' unless
 candidate&&candidate[:state]=='VALID'
newer=mapped.find{|x|x[:uploaded].to_s > candidate[:uploaded].to_s}
if newer
 puts "WARNING: A newer TestFlight binary exists: #{newer.inspect}"
end
beta=AppStoreClient.request(:get,"/v1/builds/#{candidate[:id]}/buildBetaDetail")['data']
puts 'CANDIDATE_VERIFIED '+JSON.generate(candidate.merge(beta_internal:beta.dig('attributes','internalBuildState'),
  newer_binary_found:!newer.nil?))
File.write("#{ENV.fetch('RUNNER_TEMP')}/app-review-candidate-17003.json",
 JSON.pretty_generate({versions:ios,builds:mapped,submissions:subs,candidate:candidate,newer:newer}))
