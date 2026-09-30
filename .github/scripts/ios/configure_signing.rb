require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target is missing' unless runner
runner.build_configurations.each do |config|
  next unless %w[Release Profile].include?(config.name)
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.muhajeerbooks.app'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  settings['DEVELOPMENT_TEAM'] = '8HJA5K2BQJ'
  settings['CODE_SIGN_STYLE'] = 'Manual'
  settings['CODE_SIGN_IDENTITY'] = ENV.fetch('SIGNING_CERT_SHA1')
  settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = ENV.fetch('SIGNING_CERT_SHA1')
  settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV.fetch('PROFILE_UUID')
end
project.save
puts 'Runner Release/Profile configured for manual Distribution signing, iPhone and iPad.'
