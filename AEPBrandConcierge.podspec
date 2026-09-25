Pod::Spec.new do |s|
  s.name         = "AEPBrandConcierge"
  s.version      = "5.8.0"
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
  s.dependency 'AEPCore', '>= 5.7.0', '< 6.0.0'
  s.dependency 'AEPServices', '>= 5.7.0', '< 6.0.0'
  s.dependency 'AEPEdgeIdentity', '>= 5.0.0', '< 6.0.0'
  # NOTE: Voice lives in the separate AEPVoice library, so this pod has no LiveKit dependency.
  # Voice is SPM-only: LiveKit 2.17.0 can't be resolved via CocoaPods (trunk stopped at LiveKitClient
  # 2.0.18, and its LiveKitUniFFI dependency was never published to trunk). See Option A in
  # Documentation/Implementation/voice-packaging-architecture-design.md.

  s.source_files = 'AEPBrandConcierge/Sources/**/*.swift'

end
