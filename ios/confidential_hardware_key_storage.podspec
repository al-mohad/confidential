Pod::Spec.new do |s|
  s.name             = 'confidential_hardware_key_storage'
  s.version          = '1.0.0'
  s.summary          = 'Enhanced hardware-backed key storage for Confidential package'
  s.description      = <<-DESC
Enhanced hardware-backed key storage plugin for the Confidential package.
Provides direct access to iOS Keychain and Secure Enclave features.
                       DESC
  s.homepage         = 'https://github.com/al-mohad/confidential'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Al Mohad' => 'al.mohad@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
