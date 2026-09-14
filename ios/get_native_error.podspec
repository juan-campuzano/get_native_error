#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint get_native_error.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'get_native_error'
  s.version          = '0.0.1'
  s.summary          = 'Capture native fatal signals and surface them to Dart on the next launch.'
  s.description      = <<-DESC
Installs POSIX signal handlers on iOS, persists a crash report to disk, and
returns it to Flutter after the process restarts so the app can report it.
                       DESC
  s.homepage         = 'https://github.com/juan-campuzano/get_native_error'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Juan Campuzano' => 'diegocampuzano62@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'get_native_error/Sources/get_native_error/**/*.{h,m,c}'
  s.public_header_files = 'get_native_error/Sources/get_native_error/include/**/*.h'
  s.private_header_files = 'get_native_error/Sources/get_native_error/gne_signal.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/get_native_error/Sources/get_native_error/include" "${PODS_TARGET_SRCROOT}/get_native_error/Sources/get_native_error"'
  }
end
