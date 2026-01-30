/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
@testable import AEPBrandConcierge

/// Mock text speaker for testing speech output.
final class MockTextSpeaker: TextSpeaking {
    private(set) var spokenTexts: [String] = []
    
    func utter(text: String) {
        spokenTexts.append(text)
    }
}

final class SpeechControllerTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_init_withNilCapturer_isCapturerAvailableFalse() {
        // Given / When
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // Then
        XCTAssertFalse(controller.isCapturerAvailable)
    }
    
    func test_init_withCapturer_isCapturerAvailableTrue() {
        // Given
        let capturer = MockSpeechCapturer()
        
        // When
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // Then
        XCTAssertTrue(controller.isCapturerAvailable)
    }
    
    // MARK: - isAvailable Tests
    
    func test_isAvailable_whenCapturerAvailable_returnsTrue() {
        // Given
        let capturer = MockSpeechCapturer()
        capturer.available = true
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // When / Then
        XCTAssertTrue(controller.isAvailable)
    }
    
    func test_isAvailable_whenCapturerNotAvailable_returnsFalse() {
        // Given
        let capturer = MockSpeechCapturer()
        capturer.available = false
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // When / Then
        XCTAssertFalse(controller.isAvailable)
    }
    
    func test_isAvailable_whenNoCapturer_returnsFalse() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then
        XCTAssertFalse(controller.isAvailable)
    }
    
    // MARK: - hasNeverBeenAskedForPermission Tests
    
    func test_hasNeverBeenAskedForPermission_whenNeverAsked_returnsTrue() {
        // Given
        let capturer = MockSpeechCapturer()
        capturer.neverAsked = true
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // When / Then
        XCTAssertTrue(controller.hasNeverBeenAskedForPermission)
    }
    
    func test_hasNeverBeenAskedForPermission_whenAskedBefore_returnsFalse() {
        // Given
        let capturer = MockSpeechCapturer()
        capturer.neverAsked = false
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // When / Then
        XCTAssertFalse(controller.hasNeverBeenAskedForPermission)
    }
    
    func test_hasNeverBeenAskedForPermission_whenNoCapturer_returnsTrue() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then - Default is true when no capturer
        XCTAssertTrue(controller.hasNeverBeenAskedForPermission)
    }
    
    // MARK: - configureForStreaming Tests
    
    func test_configureForStreaming_initializesCapturerWithProcessor() {
        // Given
        let capturer = MockSpeechCapturer()
        let controller = SpeechController(capturer: capturer, speaker: nil)
        var receivedText: String?
        
        // When
        controller.configureForStreaming { text in
            receivedText = text
        }
        
        // Then - Verify processor was set by calling it
        capturer.responseProcessor?("test")
        XCTAssertEqual(receivedText, "test")
    }
    
    func test_configureForStreaming_withNilCapturer_doesNotCrash() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then - Should not crash
        controller.configureForStreaming { _ in }
    }
    
    // MARK: - requestPermissions Tests
    
    func test_requestPermissions_callsCapturerRequestPermissions() {
        // Given
        let capturer = MockSpeechCapturer()
        let controller = SpeechController(capturer: capturer, speaker: nil)
        let expectation = expectation(description: "Permission request completed")
        
        // When
        controller.requestPermissions {
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturer.permissionRequests, 1)
    }
    
    // MARK: - beginCapture Tests
    
    func test_beginCapture_callsCapturerBeginCapture() {
        // Given
        let capturer = MockSpeechCapturer()
        let controller = SpeechController(capturer: capturer, speaker: nil)
        
        // When
        controller.beginCapture()
        
        // Then
        XCTAssertEqual(capturer.beginCaptures, 1)
    }
    
    func test_beginCapture_withNilCapturer_doesNotCrash() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then - Should not crash
        controller.beginCapture()
    }
    
    // MARK: - endCapture Tests
    
    func test_endCapture_callsCapturerEndCapture() {
        // Given
        let capturer = MockSpeechCapturer()
        capturer.transcriptToReturn = "Hello world"
        let controller = SpeechController(capturer: capturer, speaker: nil)
        var receivedTranscript: String?
        var receivedError: Error?
        
        // When
        controller.endCapture { transcript, error in
            receivedTranscript = transcript
            receivedError = error
        }
        
        // Then
        XCTAssertEqual(capturer.endCaptures, 1)
        XCTAssertEqual(receivedTranscript, "Hello world")
        XCTAssertNil(receivedError)
    }
    
    func test_endCapture_withNilCapturer_doesNotCrash() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then - Should not crash, completion not called
        controller.endCapture { _, _ in
            XCTFail("Completion should not be called when capturer is nil")
        }
    }
    
    // MARK: - speak Tests
    
    func test_speak_callsSpeakerUtter() {
        // Given
        let speaker = MockTextSpeaker()
        let controller = SpeechController(capturer: nil, speaker: speaker)
        
        // When
        controller.speak("Hello there")
        
        // Then
        XCTAssertEqual(speaker.spokenTexts.count, 1)
        XCTAssertEqual(speaker.spokenTexts.first, "Hello there")
    }
    
    func test_speak_withNilSpeaker_doesNotCrash() {
        // Given
        let controller = SpeechController(capturer: nil, speaker: nil)
        
        // When / Then - Should not crash
        controller.speak("Test text")
    }
    
    func test_speak_multipleTexts_accumulatesInOrder() {
        // Given
        let speaker = MockTextSpeaker()
        let controller = SpeechController(capturer: nil, speaker: speaker)
        
        // When
        controller.speak("First")
        controller.speak("Second")
        controller.speak("Third")
        
        // Then
        XCTAssertEqual(speaker.spokenTexts, ["First", "Second", "Third"])
    }
}
