Pod::Spec.new do |s|
  s.name             = 'omni_route'
  s.version          = '0.4.0'
  s.summary          = 'All-in-one Flutter plugin for routing, Bloc, onboarding persistence, networking, and native utilities.'
  s.description      = <<-DESC
All-in-one Flutter plugin combining native OS hooks, routing, Bloc scoping, local onboarding persistence, and OmniNetwork.
                       DESC
  s.homepage         = 'https://github.com/juwelzan/omni_route'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'OmniRoute Authors' => 'support@omniroute.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'omni_route/Sources/omni_route/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = { 'omni_route_privacy' => ['omni_route/Sources/omni_route/Resources/PrivacyInfo.xcprivacy'] }
end
