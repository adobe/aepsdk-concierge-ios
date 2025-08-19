#
# Copyright 2025 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

export EXTENSION_NAME = AEPConcierge
PROJECT_NAME = $(EXTENSION_NAME)
SCHEME_NAME_XCFRAMEWORK = AEPConciergeXCF
TEST_APP_IOS_SCHEME = ConciergeDemoApp

CURR_DIR := ${CURDIR}
IOS_SIMULATOR_ARCHIVE_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/Products/Library/Frameworks/
IOS_SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/dSYMs/
IOS_ARCHIVE_PATH = $(CURR_DIR)/build/ios.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios.xcarchive/dSYMs/

# CI variables with defaults. Update the defaults for local development as needed.
IOS_DEVICE_NAME ?= iPhone 16
# If OS version is not specified, uses the first device name match in the list of available simulators
IOS_VERSION ?= 
ifeq ($(strip $(IOS_VERSION)),)
    IOS_DESTINATION = "platform=iOS Simulator,name=$(IOS_DEVICE_NAME)"
else
    IOS_DESTINATION = "platform=iOS Simulator,name=$(IOS_DEVICE_NAME),OS=$(IOS_VERSION)"
endif

setup-tools: install-githook

setup:
	pod install

clean:
	rm -rf build

pod-install:
	pod install --repo-update

open:
	open $(PROJECT_NAME).xcworkspace

pod-repo-update:
	pod repo update

pod-update: pod-repo-update
	pod update

ci-pod-repo-update:
	bundle exec pod repo update

ci-pod-install:
	bundle exec pod install --repo-update

ci-pod-update: ci-pod-repo-update
	bundle exec pod update

ci-archive: ci-pod-install _archive

archive: pod-install _archive

_archive: clean build-ios
	@echo "######################################################################"
	@echo "### Generating iOS Frameworks for $(PROJECT_NAME)"
	@echo "######################################################################"
	xcodebuild -create-xcframework -framework $(IOS_SIMULATOR_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_SIMULATOR_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	-framework $(IOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM -output ./build/$(PROJECT_NAME).xcframework
	
build-ios:
	@echo "######################################################################"
	@echo "### Building iOS archive"
	@echo "######################################################################"
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ADB_SKIP_LINT=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ADB_SKIP_LINT=YES

zip:
	cd build && zip -r -X $(PROJECT_NAME).xcframework.zip $(PROJECT_NAME).xcframework/
	swift package compute-checksum build/$(PROJECT_NAME).xcframework.zip

build-app: setup
	@echo "######################################################################"
	@echo "### Building $(TEST_APP_IOS_SCHEME)"
	@echo "######################################################################"
	xcodebuild clean build -workspace $(PROJECT_NAME).xcworkspace -scheme $(TEST_APP_IOS_SCHEME) -destination 'generic/platform=iOS Simulator'

test: unit-test-ios

unit-test-ios: clean
	@echo "######################################################################"
	@echo "### Unit Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "UnitTests" -destination $(IOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/reports/iosUnitResults.xcresult -enableCodeCoverage YES ADB_SKIP_LINT=YES

functional-test-ios: clean
	@echo "######################################################################"
	@echo "### Functional Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "FunctionalTests" -destination $(IOS_DESTINATION) -resultBundlePath build/reports/iosFunctionalResults.xcresult -enableCodeCoverage YES ADB_SKIP_LINT=YES

install-githook:
	git config core.hooksPath .githooks

lint-autocorrect:
	./Pods/SwiftLint/swiftlint --fix

lint:
	./Pods/SwiftLint/swiftlint lint Sources ConciergeDemoApp

test-SPM-integration:
	sh ./Script/test-SPM.sh

test-podspec:
	sh ./Script/test-podspec.sh