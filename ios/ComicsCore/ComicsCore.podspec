# sdd-comics-editor-v2.9-android-ios: vendored NativeAOT-библиотека ядра.
# libComicsCore.a создаётся скриптом: tool/build_native.sh ios
# Подключение (после генерации Podfile первой iOS-сборкой):
#   pod 'ComicsCore', :path => 'ComicsCore'   # в target 'Runner'
Pod::Spec.new do |s|
  s.name             = 'ComicsCore'
  s.version          = '2.9.0'
  s.summary          = 'Comics Editor core (NativeAOT static library)'
  s.description      = 'C ABI (comics_call/comics_free) over the existing C# editor code.'
  s.homepage         = 'https://comics.nativemind.net'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'NativeMind'
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.vendored_libraries = 'libComicsCore.a'
  # UnmanagedCallersOnly-экспорты не должны быть выкинуты линкером:
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-force_load "$(PODS_TARGET_SRCROOT)/libComicsCore.a"'
  }
end
