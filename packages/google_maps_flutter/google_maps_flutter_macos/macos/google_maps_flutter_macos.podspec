Pod::Spec.new do |s|
  s.name             = 'google_maps_flutter_macos'
  s.version          = '0.1.0'
  s.summary          = 'Google Maps for macOS'
  s.description      = 'macOS implementation of google_maps_flutter using WKWebView'
  s.homepage         = 'https://github.com/user/google_maps_flutter_macos'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = 'Flutter'
  s.source           = { :http => 'https://github.com/user/google_maps_flutter_macos' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '11.0'
  s.swift_version = '5.0'
end
