Pod::Spec.new do |s|
  s.name        = "PingManager"
  s.version     = "1.0.0"
  s.summary     = "Ping multiple domains simultaneously"
  s.homepage    = "https://github.com/Yewenyu/PingManager"
  s.license     = { :type => "Apache License, Version 2.0" }
  s.author     = "no"
  s.module_name  = 'Socket'
  s.swift_version = '4.2'
  s.requires_arc = true
  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "10.0"
  s.tvos.deployment_target = "10.0"
  s.source   = { :git => "https://github.com/Yewenyu/PingManager.git", :tag => s.version }
  s.source_files = "PingManager/*.swift"
  s.pod_target_xcconfig =  {
        'SWIFT_VERSION' => '4.2',
  }
end