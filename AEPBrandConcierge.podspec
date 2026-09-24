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
  # NOTE: This pod ships the core Brand Concierge extension only — it has NO LiveKit dependency.
  # The real-time voice feature lives in a separate library, AEPVoice (LiveKit-backed), which is
  # distributed via Swift Package Manager and is NOT offered via CocoaPods: CocoaPods trunk stopped
  # publishing LiveKitClient at 2.0.18, and the required version (2.17.0, for AudioManager/
  # audio-session fixes) depends on LiveKitUniFFI, which was never published to trunk at all — so
  # LiveKit cannot be resolved via CocoaPods. Voice is therefore SPM-only by design (Option A in
  # Documentation/Implementation/voice-packaging-architecture-design.md); CocoaPods-based
  # integrations of this pod are unaffected and simply don't get voice. Because the LiveKit-backed
  # sources now live under AEPVoice/Sources (not AEPBrandConcierge/Sources), the glob below no
  # longer picks up any `import LiveKit`, so `pod lib lint` succeeds.

  s.source_files = 'AEPBrandConcierge/Sources/**/*.swift'

end
