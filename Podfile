source 'https://cdn.cocoapods.org/'

platform :ios, '15.0'

use_frameworks!

# don't warn me
install! 'cocoapods', :warn_for_unused_master_specs_repo => false

workspace 'AEPConcierge'
project 'AEPConcierge.xcodeproj'

pod 'SwiftLint', '0.52.0'

$dev_repo = 'https://github.com/adobe/aepsdk-concierge-ios.git'
$dev_branch = 'dev'

# ==================
# SHARED POD GROUPS
# ==================
def lib_main
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'lottie-ios'
end

def lib_dev
    pod 'lottie-ios'
    pod 'AEPCore', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPServices', :git => $dev_repo, :branch => $dev_branch
end

def app_main
    lib_main
    pod 'AEPEdge'
    pod 'AEPEdgeIdentity'
    pod 'AEPAssurance'
end

def app_dev
    lib_dev
    pod 'AEPEdge', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPEdgeIdentity', :git => $dev_repo, :branch => $dev_branch
    pod 'AEPAssurance', :git => $dev_repo, :branch => $dev_branch
end

def test_utils
     pod 'AEPTestUtils', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :tag => 'testutils-5.2.0'
end

target 'AEPConcierge' do
  lib_main
end

target 'UnitTests' do
  lib_main
end

target 'ConciergeDemoApp' do
  app_main
end
