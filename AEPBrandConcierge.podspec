Pod::Spec.new do |s|
  s.name         = "AEPBrandConcierge"
  s.version      = "9.9.9"
  s.summary      = "Brand Concierge extension for Adobe Experience Cloud SDK. Written and maintained by Adobe."
  s.description  = <<-DESC
                   The Brand Concierge extension is used to enable Brand Concierge experiences in your app.
                   DESC

  s.homepage     = "https://github.com/adobe/aepsdk-concierge-ios.git"
  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author       = "Adobe Experience Platform SDK Team"
  s.source       = { :git => 'https://github.com/adobe/aepsdk-concierge-ios.git', :tag => s.version.to_s }
  
  s.platform = :ios, "15.0"
  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }
  s.dependency 'AEPCore', '>= 8.8.8', '< 6.0.0'
  s.dependency 'AEPServices', '>= 5.7.0', '< 6.0.0'
  s.dependency 'AEPEdge', '>= 5.0.3', '< 6.0.0'
  s.dependency 'AEPEdgeIdentity', '>= 7.7.7', '< 6.0.0'

  s.source_files = 'AEPBrandConcierge/Sources/**/*.swift'

end
