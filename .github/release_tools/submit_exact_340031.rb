require_relative 'app_store_client'
def req(*a, **k) = AppStoreClient.request(*a, **k)
app = '6817641775'
version_string = '2.5.26'
number = '340031'
abort 'Exact owner approval is required' unless ENV['OWNER_APPROVED_PUBLIC_RELEASE'] == '2.5.26(340031)'
builds = req(:get, '/v1/builds', query: {'filter[app]'=>app, 'sort'=>'-uploadedDate', 'limit'=>5, 'include'=>'preReleaseVersion'})
build = builds.fetch('data').first
abort 'Latest TestFlight build changed; do not substitute it' unless build.dig('attributes','version') == number
pre = builds.fetch('included').find { |p| p['type']=='preReleaseVersions' && p['id']==build.dig('relationships','preReleaseVersion','data','id') }
abort 'Unexpected marketing version' unless pre.dig('attributes','version')==version_string
abort 'Build is not valid App Store eligible binary' unless build.dig('attributes','processingState')=='VALID' && !build.dig('attributes','expired')
beta=req(:get, "/v1/builds/#{build['id']}/buildBetaDetail").fetch('data')
abort 'Exact build is not available for internal testing' unless beta.dig('attributes','internalBuildState')=='IN_BETA_TESTING'
versions=req(:get, "/v1/apps/#{app}/appStoreVersions", query: {'limit'=>100}).fetch('data')
version=versions.find { |v| v.dig('attributes','platform')=='IOS' && v.dig('attributes','versionString')==version_string }
unless version
  version=req(:post, '/v1/appStoreVersions', body:{data:{type:'appStoreVersions',attributes:{platform:'IOS',versionString:version_string,releaseType:'AFTER_APPROVAL'},relationships:{app:{data:{type:'apps',id:app}}}}}).fetch('data')
end
id=version.fetch('id')
state=version.dig('attributes','appStoreState')
attached=req(:get, "/v1/appStoreVersions/#{id}/relationships/build")['data']
editable=%w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED READY_FOR_REVIEW METADATA_REJECTED]
if editable.include?(state)
  req(:patch, "/v1/appStoreVersions/#{id}", body:{data:{type:'appStoreVersions',id:id,attributes:{releaseType:'AFTER_APPROVAL'}}})
  req(:patch, "/v1/appStoreVersions/#{id}/relationships/build", body:{data:{type:'builds',id:build.fetch('id')}}) unless attached && attached['id']==build['id']
  locales=req(:get, "/v1/appStoreVersions/#{id}/appStoreVersionLocalizations", query:{'limit'=>100}).fetch('data')
  abort 'No copied store listing localizations' if locales.empty?
  locales.each do |loc|
    language=loc.dig('attributes','locale')
    notes=case language
    when /^ko/ then '도서 추천과 예약 주문을 개선했습니다. 예약 도서 도착 기간과 선불금 처리, 주문 관리 및 관리자 재무 현황을 개선했습니다.'
    when /^ru/ then 'Улучшены рекомендации книг, предзаказы, сроки поступления и учет аванса. Обновлены управление заказами и финансовые показатели для администратора.'
    when /^uz/ then 'Kitob tavsiyalari, oldindan buyurtmalar, kelish sanalari va avans hisobi yaxshilandi. Buyurtmalar boshqaruvi va partiyalar moliyaviy ko‘rsatkichlari yangilandi.'
    else 'Improved book recommendations, preorders, arrival date ranges and advance payment handling. Updated order management and batch financial summaries for administrators.'
    end
    req(:patch, "/v1/appStoreVersionLocalizations/#{loc['id']}", body:{data:{type:'appStoreVersionLocalizations',id:loc['id'],attributes:{whatsNew:notes}}})
  end
  submissions=req(:get, "/v1/apps/#{app}/reviewSubmissions", query:{'limit'=>100}).fetch('data')
  review=submissions.find do |r|
    next false unless r.dig('attributes','state')=='READY_FOR_REVIEW'
    items=req(:get, "/v1/reviewSubmissions/#{r['id']}/items", query:{'limit'=>100}).fetch('data')
    items.any? { |i| i.dig('relationships','appStoreVersion','data','id')==id }
  end
  review ||= req(:post, '/v1/reviewSubmissions', body:{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:{data:{type:'apps',id:app}}}}}).fetch('data')
  rid=review.fetch('id')
  items=req(:get, "/v1/reviewSubmissions/#{rid}/items", query:{'limit'=>100}).fetch('data')
  unless items.any? { |i| i.dig('relationships','appStoreVersion','data','id')==id }
    req(:post, '/v1/reviewSubmissionItems', body:{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:{data:{type:'reviewSubmissions',id:rid}},appStoreVersion:{data:{type:'appStoreVersions',id:id}}}}})
  end
  review=req(:patch, "/v1/reviewSubmissions/#{rid}", body:{data:{type:'reviewSubmissions',id:rid,attributes:{submitted:true}}}).fetch('data')
  puts "REVIEW_STATE=#{review.dig('attributes','state')}"
elsif !%w[WAITING_FOR_REVIEW IN_REVIEW PENDING_APPLE_RELEASE PROCESSING_FOR_APP_STORE READY_FOR_SALE].include?(state)
  abort "Cannot safely submit from state #{state}"
end
final=req(:get, "/v1/appStoreVersions/#{id}").fetch('data')
attachment=req(:get, "/v1/appStoreVersions/#{id}/relationships/build").fetch('data')
abort 'Wrong build attachment' unless attachment['id']==build['id']
abort 'Automatic release not configured' unless final.dig('attributes','releaseType')=='AFTER_APPROVAL'
evidence={version:version_string,build:number,build_id:build['id'],version_id:id,state:final.dig('attributes','appStoreState'),release_type:final.dig('attributes','releaseType'),new_binary_created:false}
File.write("#{ENV.fetch('RUNNER_TEMP')}/ios-final-submission.json",JSON.pretty_generate(evidence))
puts JSON.pretty_generate(evidence)
