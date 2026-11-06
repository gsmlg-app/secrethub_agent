Pod::Spec.new do |s|
  s.name             = 'secrethub_agent'
  s.version          = '0.0.1'
  s.summary          = 'SecretHub mobile agent plugin bootstrap for iOS and Android.'
  s.description      = s.summary
  s.homepage         = 'https://github.com/gsmlg-app/secrethub_agent'
  s.author           = 'gsmlg-app'
  s.source           = { :path => '.' }
  s.source_files     = 'secrethub_agent/Sources/secrethub_agent/**/*.{h,m,swift}'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.resource_bundles = {
    'secrethub_agent_privacy' => ['secrethub_agent/Sources/secrethub_agent/PrivacyInfo.xcprivacy']
  }
end
