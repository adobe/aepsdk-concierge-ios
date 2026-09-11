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

/// Covers the pure noise-floor/gain-compensation math in `SpeechCapturer` — the part of the "voice to text is
/// endless" fix that doesn't require real `AVAudioEngine`/`AVAudioSession` hardware to verify. Route-change and
/// audio-session behavior are intentionally not covered here; those were verified on-device.
final class SpeechCapturerTests: XCTestCase {

    // MARK: - gainCompensatedRMS

    func test_gainCompensatedRMS_rmsEqualsFloor_mapsToTargetReference() {
        let capturer = SpeechCapturer()
        let floor: Float = 0.001 // above minimumNoiseFloorRMS, so the clamp doesn't engage

        let corrected = capturer.gainCompensatedRMS(rms: floor, floor: floor)

        XCTAssertEqual(corrected, SpeechCapturer.targetFloorReferenceRMS, accuracy: 0.000001)
    }

    func test_gainCompensatedRMS_atValidatedThreeTimesFloor_equalsDefaultThreshold() {
        let capturer = SpeechCapturer()
        let floor: Float = 0.001

        let corrected = capturer.gainCompensatedRMS(rms: floor * 3.0, floor: floor)

        XCTAssertEqual(corrected, 0.02, accuracy: 0.0001)
    }

    /// Regression test for the AirPods bug: an unusually quiet calibration (~0.00005 RMS, far below
    /// minimumNoiseFloorRMS) must not produce a gain large enough to misread post-speech breathing/mouth noise
    /// (~0.0005 RMS observed) as continued speech.
    func test_gainCompensatedRMS_extremelyLowFloor_rejectsPostSpeechBreathNoise() {
        let capturer = SpeechCapturer()
        let airPodsStyleFloor: Float = 0.00005
        let observedBreathNoiseRMS: Float = 0.0005

        let corrected = capturer.gainCompensatedRMS(rms: observedBreathNoiseRMS, floor: airPodsStyleFloor)

        XCTAssertLessThan(corrected, 0.02)
    }

    // MARK: - detectSilence

    /// Regression test for the mid-sentence cutoff bug: once speech has been detected, brief quiet gaps
    /// (pauses between words/breaths) must not drift the noise floor upward.
    func test_detectSilence_afterSpeechDetected_doesNotAdaptFloorOnQuietGap() {
        let capturer = SpeechCapturer()
        let floor: Float = 0.001
        capturer.noiseFloor = floor

        let loudRms = floor * 5
        capturer.detectSilence(correctedRms: capturer.gainCompensatedRMS(rms: loudRms, floor: floor), rawRms: loudRms, floor: floor)
        XCTAssertTrue(capturer.hasSpokeOnce)

        let quietRms = floor * 0.5
        capturer.detectSilence(correctedRms: capturer.gainCompensatedRMS(rms: quietRms, floor: floor), rawRms: quietRms, floor: floor)

        XCTAssertEqual(capturer.noiseFloor, floor)
    }

    func test_detectSilence_beforeSpeechDetected_adaptsFloorOnQuietSample() {
        let capturer = SpeechCapturer()
        let initialFloor: Float = 0.001
        capturer.noiseFloor = initialFloor

        let quietRms: Float = 0.0005
        capturer.detectSilence(correctedRms: capturer.gainCompensatedRMS(rms: quietRms, floor: initialFloor), rawRms: quietRms, floor: initialFloor)

        XCTAssertFalse(capturer.hasSpokeOnce)
        XCTAssertNotEqual(capturer.noiseFloor, initialFloor)
    }

    func test_detectSilence_afterSilenceDurationElapsed_firesSilenceHandlerAndResetsHasSpokeOnce() {
        let capturer = SpeechCapturer()
        let floor: Float = 0.001
        capturer.noiseFloor = floor
        capturer.hasSpokeOnce = true
        capturer.silenceStart = Date().addingTimeInterval(-10) // well past the default 2.0s duration

        let handlerFired = expectation(description: "silenceHandler fires")
        capturer.silenceHandler = { handlerFired.fulfill() }

        let quietRms: Float = 0.0002
        capturer.detectSilence(correctedRms: capturer.gainCompensatedRMS(rms: quietRms, floor: floor), rawRms: quietRms, floor: floor)

        wait(for: [handlerFired], timeout: 1.0)
        XCTAssertFalse(capturer.hasSpokeOnce)
    }

    func test_detectSilence_quietBeforeSilenceDurationElapsed_doesNotFireSilenceHandler() {
        let capturer = SpeechCapturer()
        let floor: Float = 0.001
        capturer.noiseFloor = floor
        capturer.hasSpokeOnce = true
        capturer.silenceStart = Date() // just started, nowhere near the 2.0s default duration

        var handlerFired = false
        capturer.silenceHandler = { handlerFired = true }

        let quietRms: Float = 0.0002
        capturer.detectSilence(correctedRms: capturer.gainCompensatedRMS(rms: quietRms, floor: floor), rawRms: quietRms, floor: floor)

        XCTAssertFalse(handlerFired)
        XCTAssertTrue(capturer.hasSpokeOnce)
    }

    // MARK: - calibratedNoiseFloor

    func test_calibratedNoiseFloor_duringCalibrationWindow_returnsNil() {
        let capturer = SpeechCapturer()
        capturer.resetSilenceDetectionState()

        let result = capturer.calibratedNoiseFloor(for: 0.0003)

        XCTAssertNil(result)
    }

    func test_calibratedNoiseFloor_afterWindowElapses_averagesAccumulatedSamples() throws {
        let capturer = SpeechCapturer()
        capturer.resetSilenceDetectionState()

        XCTAssertNil(capturer.calibratedNoiseFloor(for: 0.0002))
        XCTAssertNil(capturer.calibratedNoiseFloor(for: 0.0004))

        // Simulate the calibration window having elapsed without a real sleep.
        capturer.captureStartTime = Date().addingTimeInterval(-1)
        let floor = try XCTUnwrap(capturer.calibratedNoiseFloor(for: 0.0006))

        XCTAssertEqual(floor, 0.0003, accuracy: 0.00001)
    }

    func test_calibratedNoiseFloor_onceCalibrated_ignoresFurtherSamples() {
        let capturer = SpeechCapturer()
        capturer.resetSilenceDetectionState()
        capturer.captureStartTime = Date().addingTimeInterval(-1)
        let floor = capturer.calibratedNoiseFloor(for: 0.0005)

        let secondCall = capturer.calibratedNoiseFloor(for: 0.9)

        XCTAssertEqual(secondCall, floor)
    }
}
