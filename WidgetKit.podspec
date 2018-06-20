Pod::Spec.new do |s|
  s.name     = "WidgetKit"
  s.version  = "1.0.0"
  s.platform = :ios
  s.summary  = "Lightweight iOS framework for creating codeless native apps."
  s.homepage = "https://github.com/faviomob/WidgetKit"
  s.license  = { :type => "MIT", :file => "LICENSE.md" }
  s.author   = { "Favio Mobile" => "faviomob@gmail.com" }
  s.source   = { :git => "https://github.com/faviomob/WidgetKit.git", :tag => s.version.to_s }

  s.swift_version = "4.1"

  s.ios.deployment_target = "10.0"
  s.ios.source_files = "WidgetKit/Sources/**/*.swift"

  s.dependency "Groot"
  s.dependency "AlamofireImage", "~> 3.3"
  s.dependency "ZIPFoundation"

end
