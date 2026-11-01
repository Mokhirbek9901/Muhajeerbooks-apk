# frozen_string_literal: true
# Owner-requested submission of the exact verified TestFlight 2.5.23 (17003).
# Do not rebuild, change an existing live version, or silently remove review items.
require_relative 'app_store_client'
require 'json'

APP_ID = '6817641775'
VERSION = '2.5.23'
BUILD = '17003'
EXPECTED_BUILD_ID = '1cd78854-823b-48a5-a002-d9b0d3ac682d'
OUT = "#{ENV.fetch('RUNNER_TEMP')}/ios-public-17003-result.json"
abort 'Missing owner approval of the exact update' unless
  ENV['OWNER_APPROVED_IOS_PUBLIC_UPDATE'] == "com.muhajeerbooks.app:#{VERSION}:#{BUILD}"
abort 'Must run against the selected TestFlight source branch' unless
  ENV['GITHUB_REF_NAME'] == 'ios-server-update-prompt-20261102'

def asc(*args, **opts)
  AppStoreClient.request(*args, **opts)
end

def write_evidence(value)
  File.write(OUT, JSON.pretty_generate(value))
end

evidence = {
  app_id: APP_ID,
  version: VERSION,
  build: BUILD,
  build_id: EXPECTED_BUILD_ID,
  candidate_run_id: 41353265829,
  candidate_sha: 'b4349843199ee9d08b4ab953a881905a67777579',
  result: 'not_submitted'
}
begin
  apps = asc(:get, '/v1/apps', query: { 'filter[bundleId]' => 'com.muhajeerbooks.app', 'limit' => 2 }).fetch('data')
  abort 'App Store app mismatch' unless apps.length == 1 && apps.first['id'] == APP_ID
  versions = asc(:get, "/v1/apps/#{APP_ID}/appStoreVersions", query: {
    'limit' => 100, 'fields[appStoreVersions]' => 'platform,versionString,appStoreState,releaseType,build'
  }).fetch('data').select { |v| v.dig('attributes', 'platform') == 'IOS' }
  target = versions.find { |v| v.dig('attributes', 'versionString') == VERSION }
  if target
    state = target.dig('attributes', 'appStoreState')
    puts "Existing #{VERSION}: #{state}"
    if %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE READY_FOR_SALE].include?(state)
      attached = asc(:get, "/v1/appStoreVersions/#{target.fetch('id')}/relationships/build")['data']
      if attached && attached['id'] == EXPECTED_BUILD_ID
        evidence.update(result: 'already_submitted_or_released', app_store_state: state,
          version_id: target.fetch('id'))
        write_evidence(evidence)
        puts "VERIFIED: exact #{VERSION} (#{BUILD}) is already #{state}, no duplicate submission."
        exit 0
      end
      abort "Unrelated build in #{state}; do not cancel an existing review"
    end
    abort "App Store version is not editable: #{state}" unless
      %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED METADATA_REJECTED REJECTED].include?(state)
  end

  builds = asc(:get, '/v1/builds', query: {
    'filter[app]' => APP_ID, 'filter[version]' => BUILD,
    'include' => 'preReleaseVersion', 'limit' => 30
  })
  selected = builds.fetch('data').find do |b|
    pre_id = b.dig('relationships', 'preReleaseVersion', 'data', 'id')
    pre = builds.fetch('included', []).find { |item| item['id'] == pre_id }
    b['id'] == EXPECTED_BUILD_ID &&
      b.dig('attributes', 'version') == BUILD &&
      b.dig('attributes', 'processingState') == 'VALID' &&
      pre && pre.dig('attributes', 'platform') == 'IOS' &&
      pre.dig('attributes', 'version') == VERSION
  end
  abort 'Expected validated 17003 TestFlight binary not found' unless selected
  beta = asc(:get, "/v1/builds/#{EXPECTED_BUILD_ID}/buildBetaDetail")['data']
  puts "Selected TestFlight #{VERSION}(#{BUILD}) beta=#{beta.dig('attributes','internalBuildState')}"
  evidence[:processing_state] = 'VALID'

  active = asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions", query: {'limit'=>100}).fetch('data')
    .select { |r| %w[WAITING_FOR_REVIEW IN_REVIEW].include?(r.dig('attributes','state')) }
  abort 'Another active App Review submission exists; leave it unchanged' unless active.empty?

  unless target
    target = asc(:post, '/v1/appStoreVersions', body: {
      data: {type: 'appStoreVersions',
        attributes: {platform: 'IOS', versionString: VERSION, releaseType: 'AFTER_APPROVAL'},
        relationships: {app: {data: {type: 'apps', id: APP_ID}}}}
    }).fetch('data')
    puts "Created App Store version #{VERSION}; approval will automatically publish the update."
  end
  id = target.fetch('id')
  evidence[:version_id] = id
  attached = asc(:get, "/v1/appStoreVersions/#{id}/relationships/build")['data']
  unless attached && attached['id'] == EXPECTED_BUILD_ID
    abort 'A different build is already attached; stop instead of replacing it' if attached
    asc(:patch, "/v1/appStoreVersions/#{id}/relationships/build",
      body: {data: {type: 'builds', id: EXPECTED_BUILD_ID}})
  end
  check = asc(:get, "/v1/appStoreVersions/#{id}/relationships/build")['data']
  abort 'App Store is not using exactly build 17003' unless check && check['id'] == EXPECTED_BUILD_ID
  evidence[:build_attached] = true

  locales = asc(:get, "/v1/appStoreVersions/#{id}/appStoreVersionLocalizations",
    query: { 'limit' => 100 }).fetch('data')
  puts "Existing localization records: #{locales.length}"
  if locales.empty?
    # Existing App Store content and screenshot metadata remain untouched.
    # Apple may create a localization automatically; otherwise add the default.
    created = asc(:post, '/v1/appStoreVersionLocalizations', body: {
      data: {type: 'appStoreVersionLocalizations',
        attributes: {locale: 'en-US'},
        relationships: {appStoreVersion: {data: {type: 'appStoreVersions', id: id}}}}
    }).fetch('data')
    locales = [created]
  end
  notes = {
    'uz' => 'Ilovada yangi versiya chiqqanda App Store orqali yangilash haqida eslatma beriladi. Oldindan buyurtmalarda kelgan kitoblarni alohida belgilash va avansni taqsimlash yaxshilandi. Kitob rasmlari va buyurtma oynalari saqlandi.',
    'ko' => '새 버전이 출시되면 App Store 업데이트 안내를 표시합니다. 예약 주문의 부분 입고 선택 및 선결제금 배분을 개선했습니다. 도서 표지와 주문 화면을 유지합니다.',
    'ru' => 'Добавлено уведомление о доступном обновлении через App Store. Улучшен выбор частично поступивших книг и распределение аванса в предзаказах. Сохранены обложки и экраны заказов.',
    'en' => 'Get notified when a newer App Store version is available. Improved partial preorder arrivals and deposit allocation while preserving book cover previews and order screens.'
  }
  locales.each do |loc|
    lang = loc.dig('attributes','locale').to_s.downcase.split('-').first
    value = notes.fetch(lang, notes['en'])
    asc(:patch, "/v1/appStoreVersionLocalizations/#{loc.fetch('id')}", body: {
      data: {type: 'appStoreVersionLocalizations', id: loc.fetch('id'),
        attributes: {whatsNew: value}}
    })
  end
  evidence[:localizations_updated] = locales.map { |loc| loc.dig('attributes','locale') }
  puts "Updated release notes for #{locales.length} localizations."

  review = asc(:get, "/v1/apps/#{APP_ID}/reviewSubmissions", query: {'limit'=>100})
    .fetch('data').find { |item| item.dig('attributes','state') == 'READY_FOR_REVIEW' }
  review ||= asc(:post, '/v1/reviewSubmissions', body: {
    data: {type: 'reviewSubmissions',
      relationships: {app: {data: {type: 'apps', id: APP_ID}}}}
  }).fetch('data')
  review_id = review.fetch('id')
  evidence[:review_submission_id] = review_id
  items = asc(:get, "/v1/reviewSubmissions/#{review_id}/items", query: {'limit'=>100}).fetch('data')
  unless items.any? { |item| item.dig('relationships','appStoreVersion','data','id') == id }
    asc(:post, '/v1/reviewSubmissionItems', body: {
      data: {type: 'reviewSubmissionItems', relationships: {
        reviewSubmission: {data: {type: 'reviewSubmissions', id: review_id}},
        appStoreVersion: {data: {type: 'appStoreVersions', id: id}}
      }}
    })
  end
  evidence[:result] = 'prepared_for_apple_submission'
  write_evidence(evidence)
  submitted = asc(:patch, "/v1/reviewSubmissions/#{review_id}", body: {
    data: {type: 'reviewSubmissions', id: review_id, attributes: {submitted: true}}
  })
  evidence[:result] = 'submitted_to_apple_review'
  evidence[:submission_state] = submitted.dig('data','attributes','state')
  updated = asc(:get, "/v1/appStoreVersions/#{id}")['data']
  evidence[:app_store_state] = updated.dig('attributes','appStoreState')
  puts "SUBMITTED: #{VERSION} (#{BUILD}) to Apple App Review, review=#{evidence[:submission_state]}, appStore=#{evidence[:app_store_state]}"
rescue => e
  evidence[:error] = "#{e.class}: #{e.message}"
  raise
ensure
  write_evidence(evidence)
end
