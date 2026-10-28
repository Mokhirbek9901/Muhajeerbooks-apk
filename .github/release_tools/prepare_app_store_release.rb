require_relative 'app_store_client'

BUNDLE_ID = 'com.muhajeerbooks.app'
TARGET_VERSION = ENV.fetch('IOS_MARKETING_VERSION')
TARGET_BUILD = ENV.fetch('IOS_BUILD_NUMBER')

def request(*args, **kwargs)
  AppStoreClient.request(*args, **kwargs)
end

# A draft is prepared for the exact processed test build. Never submit or release it.
apps = request(:get, '/v1/apps', query: { 'filter[bundleId]' => BUNDLE_ID, 'limit' => 2 }).fetch('data')
abort 'Expected one app record' unless apps.length == 1
app_id = apps.first.fetch('id')
fields = 'platform,versionString,appStoreState,build,releaseType'
versions = request(:get, "/v1/apps/#{app_id}/appStoreVersions", query: { 'limit' => 100, 'fields[appStoreVersions]' => fields }).fetch('data')
ios = versions.select { |v| v.dig('attributes','platform') == 'IOS' }
editable = %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED READY_FOR_REVIEW METADATA_REJECTED]
unreleased = editable + %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE WAITING_FOR_EXPORT_COMPLIANCE]
ios.each do |v|
  state = v.dig('attributes','appStoreState') || v.dig('attributes','appVersionState')
  puts "iOS #{v.dig('attributes','versionString')}: #{state}, release=#{v.dig('attributes','releaseType')}"
  next unless unreleased.include?(state)
  request(:patch, "/v1/appStoreVersions/#{v.fetch('id')}", body: { data: { type: 'appStoreVersions', id: v.fetch('id'), attributes: { releaseType: 'MANUAL' } } })
end
builds = request(:get, '/v1/builds', query: { 'filter[app]' => app_id, 'filter[version]' => TARGET_BUILD, 'include' => 'preReleaseVersion', 'limit' => 50 })
build = builds.fetch('data').find do |b|
  pre = builds.fetch('included',[]).find { |r| r['id'] == b.dig('relationships','preReleaseVersion','data','id') }
  pre && pre.dig('attributes','version') == TARGET_VERSION && b.dig('attributes','processingState') == 'VALID'
end
abort 'The exact tested build is not VALID' unless build
version = ios.find { |v| v.dig('attributes','versionString') == TARGET_VERSION }
unless version
  version = request(:post, '/v1/appStoreVersions', body: { data: { type: 'appStoreVersions', attributes: { platform: 'IOS', versionString: TARGET_VERSION, releaseType: 'MANUAL' }, relationships: { app: { data: { type: 'apps', id: app_id } } } } }).fetch('data')
end
version_id = version.fetch('id')
state = version.dig('attributes','appStoreState') || version.dig('attributes','appVersionState')
abort "Refusing to modify a live or noneditable version: #{state}" unless unreleased.include?(state)
request(:patch, "/v1/appStoreVersions/#{version_id}", body: { data: { type: 'appStoreVersions', id: version_id, attributes: { releaseType: 'MANUAL' } } })
attached = request(:get, "/v1/appStoreVersions/#{version_id}/relationships/build")['data']
already_attached = attached && attached['id'] == build.fetch('id')
if %w[WAITING_FOR_REVIEW IN_REVIEW].include?(state) && !already_attached
  submissions = request(:get, "/v1/apps/#{app_id}/reviewSubmissions", query: { 'limit' => 100, 'include' => 'appStoreVersionForReview' }).fetch('data')
  active = submissions.select { |s| %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES].include?(s.dig('attributes','state')) }
  submission = active.find do |s|
    s.dig('relationships','appStoreVersionForReview','data','id') == version_id ||
      request(:get, "/v1/reviewSubmissions/#{s.fetch('id')}/items", query: { 'limit' => 100 }).fetch('data').any? { |i| i.dig('relationships','appStoreVersion','data','id') == version_id }
  end
  abort 'Could not locate this outdated review; manual release is held, but attaching the new test build is blocked.' unless submission
  request(:patch, "/v1/reviewSubmissions/#{submission.fetch('id')}", body: { data: { type: 'reviewSubmissions', id: submission.fetch('id'), attributes: { canceled: true } } })
  deadline = Time.now + 240
  loop do
    current = request(:get, "/v1/appStoreVersions/#{version_id}").fetch('data')
    state = current.dig('attributes','appStoreState') || current.dig('attributes','appVersionState')
    break if editable.include?(state)
    abort "Manual hold set; old review cancellation still pending: #{state}" if Time.now >= deadline
    sleep 10
  end
end
abort "Manual hold set, but build cannot be replaced in #{state}" unless editable.include?(state) || already_attached
unless already_attached
  request(:patch, "/v1/appStoreVersions/#{version_id}/relationships/build", body: { data: { type: 'builds', id: build.fetch('id') } })
end
if editable.include?(state)
  locales = request(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations", query: { 'limit' => 100 }).fetch('data')
  locales.each do |locale|
    language = locale.dig('attributes','locale').to_s
    notes = if language.start_with?('ru')
      'Все фотографии книг в каталоге, улучшенная загрузка изображений и оформление предзаказов с вычетом аванса. Исправлены закрытие клавиатуры и ошибки запуска. Улучшена стабильность приложения.'
    elsif language.start_with?('ko')
      '도서의 모든 사진을 볼 수 있으며 이미지 업로드를 개선했습니다. 예약 주문의 선불금 공제, 키보드 닫기 및 앱 시작 오류를 수정하고 안정성을 개선했습니다.'
    elsif language.start_with?('uz')
      'Kitoblarning barcha rasmlari, qulay rasm yuklash, avans ayiriladigan oldindan buyurtmalar. Klaviaturani yopish va ilovani ishga tushirish yaxshilandi.'
    else
      'Browse every book photo with improved image uploads. Preorders correctly deduct paid advances. Improved keyboard dismissal, order validation, startup recovery and overall stability.'
    end
    request(:patch, "/v1/appStoreVersionLocalizations/#{locale.fetch('id')}", body: { data: { type: 'appStoreVersionLocalizations', id: locale.fetch('id'), attributes: { whatsNew: notes } } })
  end
end
verified = request(:get, "/v1/appStoreVersions/#{version_id}", query: { 'fields[appStoreVersions]' => fields }).fetch('data')
abort 'Manual release hold was not verified' unless verified.dig('attributes','releaseType') == 'MANUAL'
attachment_deadline = Time.now + 60
loop do
  attached = request(:get, "/v1/appStoreVersions/#{version_id}/relationships/build")['data']
  break if attached && attached['id'] == build.fetch('id')
  abort 'The exact tested build was not attached' if Time.now >= attachment_deadline
  sleep 3
end
puts "VERIFIED exact App Store build relationship: #{attached.fetch('id')}"
evidence = { version: TARGET_VERSION, build_number: TARGET_BUILD, app_store_version_id: version_id, build_id: build.fetch('id'), release_type: 'MANUAL', app_store_state: verified.dig('attributes','appStoreState'), new_review_submitted: false, public_release_allowed: false, owner_test_approval: 'pending' }
File.write("#{ENV.fetch('RUNNER_TEMP')}/app-store-candidate.json", JSON.pretty_generate(evidence))
puts "VERIFIED: #{TARGET_VERSION} (#{TARGET_BUILD}) attached to a MANUAL App Store draft. No new review submission or public release performed. Owner test approval pending."
