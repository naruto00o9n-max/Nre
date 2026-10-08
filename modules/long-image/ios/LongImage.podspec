Pod::Spec.new do |s|
  s.name = 'LongImage'
  s.version = '0.2.0'
  s.summary = 'Disk-backed image tiles and streaming PNG for Manhwa Studio'
  s.description = s.summary
  s.license = { :type => 'MIT', :file => '../../../LICENSE' }
  s.author = 'Manhwa Studio'
  s.homepage = 'https://github.com/naruto00o9n-max/Nre'
  s.source = { :git => 'https://github.com/naruto00o9n-max/Nre.git' }
  s.platforms = { :ios => '16.4' }
  s.swift_version = '5.9'
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '*.swift', 'PixelCore.{c,h}', 'Vendor/libpng/*.{c,h}'
  s.public_header_files = 'PixelCore.h'
  s.private_header_files = 'Vendor/libpng/*.h'
  s.libraries = 'z'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) PNG_ARM_NEON_OPT=0'
  }
end
