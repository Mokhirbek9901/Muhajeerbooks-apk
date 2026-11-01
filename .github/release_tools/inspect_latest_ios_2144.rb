require_relative 'app_store_client'
require 'json'
req = ->(m,p,q=nil) { AppStoreClient.request(m,p,query:q) }
apps=req.call(:get,'/v1/apps',{'filter[bundleId]'=>'com.muhajeerbooks.app','limit'=>2}).fetch('data')
abort 'Expected exactly one iOS app' unless apps.length==1
app_id=apps.first.fetch('id')
versions=req.call(:get,"/v1/apps/#{app_id}/appStoreVersions",{
'limit'=>100,'fields[appStoreVersions]'=>'platform,versionString,appStoreState,releaseType,build'
}).fetch('data').select{|v|v.dig('attributes','platform')=='IOS'}
rows=[]
versions.each do |v|
 id=v.fetch('id')
 b=req.call(:get,"/v1/appStoreVersions/#{id}/relationships/build")['data'] rescue nil
 rows<<{id:id,version:v.dig('attributes','versionString'),state:v.dig('attributes','appStoreState'),
 release_type:v.dig('attributes','releaseType'),attached_build_id:b&&b['id']}
end
builds=req.call(:get,'/v1/builds',{'filter[app]'=>app_id,'filter[version]'=>'2144',
'include'=>'preReleaseVersion','limit'=>20})
pr=builds.fetch('included',[])
selected=builds.fetch('data').select do |b|
 ref=b.dig('relationships','preReleaseVersion','data','id')
 x=pr.find{|i|i['id']==ref}
 x&&x.dig('attributes','version')=='2.5.22'&&x.dig('attributes','platform')=='IOS'
end.map{|b|{id:b['id'],number:b.dig('attributes','version'),state:b.dig('attributes','processingState'),uploaded:b.dig('attributes','uploadedDate')}}
submissions=req.call(:get,"/v1/apps/#{app_id}/reviewSubmissions",{'limit'=>100}).fetch('data')
reviews=submissions.map{|r|{id:r['id'],state:r.dig('attributes','state'),
 app_store_version_id:r.dig('relationships','appStoreVersionForReview','data','id')}}
result={app_id:app_id,versions:rows,build_2144:selected,submissions:reviews}
puts JSON.pretty_generate(result)
File.write("#{ENV.fetch('RUNNER_TEMP')}/ios-review-inspection.json",JSON.pretty_generate(result))
