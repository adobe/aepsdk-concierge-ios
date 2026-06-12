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

/// Data-driven, multi-turn timing tests against the real Concierge backend.
///
/// Scenarios are read from the bundled `scenarios.json`. Each scenario is an independent
/// conversation (the app is relaunched with `--reset-session` between scenarios). A scenario
/// runs its turns in order; after each turn the runner reads that turn's SSE → render timeline
/// and evaluates the turn's optional `stopWhen` condition:
///   - if `stopWhen` is present and matches the result (e.g. we got product cards) → the
///     scenario stops early (we got what we wanted);
///   - otherwise the next turn is sent in the same conversation (the conditional follow-up).
///
/// Per-turn timeline fields (see TurnTiming in the app):
///   ttfb, chunks/in-progress, COMPLETED offset, stream, render-after-complete, total,
///   plus the result classification: cardCount, responseEmpty, textLength, renderedMessageCount.
///
/// Prerequisites:
///   1. Network access to the real backend (demo app config in AppDelegate.swift).
///   2. **Disable the simulator hardware keyboard** so typing works:
///      Simulator menu ▸ I/O ▸ Keyboard ▸ uncheck "Connect Hardware Keyboard" (⇧⌘K).
///   3. Debug build (the timeline JSON is DEBUG-only).
///
/// Results: a combined `scenario-results.json` is attached to the test (Report navigator),
/// extractable with: `xcrun xcresulttool export attachments --path <result>.xcresult --output-path <dir>`.
final class ConversationScenarioTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        // Keep going through all scenarios even if one fails, so a single bad scenario does
        // not hide the results of the others.
        continueAfterFailure = true
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Driver

    func test_runScenariosFromJSON() throws {
        let file = try loadScenarios()
        let timeout = TimeInterval(file.responseTimeoutSeconds ?? 60)
        var results = ScenarioResultsFile(scenarios: [])

        for scenario in file.scenarios {
            var scenarioResult = ScenarioResult(id: scenario.id, name: scenario.name, turns: [])

            XCTContext.runActivity(named: "\(scenario.id) — \(scenario.name)") { _ in
                launchFresh()  // independent conversation per scenario

                var lastSubmitMs: Int64 = 0
                for (index, turn) in scenario.turns.enumerated() {
                    var timeline: Timeline?
                    XCTContext.runActivity(named: "turn \(index + 1): \(turn.prompt.truncated(to: 40))") { _ in
                        sendTurn(prompt: turn.prompt, id: scenario.id, turnIndex: index + 1, timeout: timeout)
                        // Timing is already locked in here: the app stamps render-complete when
                        // chatState returns to idle (busy probe gone), before any scrolling.
                        timeline = readTimeline(after: lastSubmitMs, timeout: 8)
                        // After load, surface the full response, then pause briefly. This happens
                        // AFTER the measurement, so it does not affect the timeline.
                        if let actions = turn.actions {
                            performActions(actions)            // config-driven
                        } else {
                            scrollConversationToEnd()          // default: scroll to end…
                            if let t = timeline, t.cardCount > 0 {
                                scrollCardCarousel()           // …+ cards when present
                            }
                        }
                        Thread.sleep(forTimeInterval: 1.0)
                    }

                    guard let t = timeline else {
                        XCTFail("[\(scenario.id)] turn \(index + 1): no timeline read (prompt: \"\(turn.prompt)\")")
                        break
                    }
                    lastSubmitMs = t.submitMs
                    scenarioResult.turns.append(t)
                    reportTurn(scenarioId: scenario.id, turnIndex: index + 1, prompt: turn.prompt, timing: t)

                    // Conditional follow-up: stop the scenario once the result is satisfactory.
                    if let stop = turn.stopWhen, stop.matches(t) { break }
                }
            }

            results.scenarios.append(scenarioResult)
        }

        attachSummary(results)
        attachResults(results)
    }

    // MARK: - App lifecycle

    /// Relaunches the app with a cleared session so the scenario starts a fresh conversation.
    private func launchFresh() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--reset-session"]
        app.launch()
        do {
            try openChat()
        } catch {
            XCTFail("Failed to open chat: \(error)")
        }
    }

    private func openChat() throws {
        let openButton = app.buttons.matching(identifier: "demo.openChatButton").firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 10),
                      "Could not find the 'Open chat' button — is the app on the SwiftUI tab?")
        openButton.tap()

        let input = app.textViews.matching(identifier: "concierge.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10),
                      "Chat input field did not appear after tapping 'Open chat'.")
    }

    // MARK: - One turn

    /// Types `prompt`, sends it, and waits for the chat to return to idle (render complete).
    private func sendTurn(prompt: String, id: String, turnIndex: Int, timeout: TimeInterval) {
        let input = app.textViews.matching(identifier: "concierge.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10), "[\(id)] turn \(turnIndex): input not found")

        input.tap()
        // The keyboard may take a moment to appear; if the hardware keyboard is connected it
        // never shows and typing fails (see prerequisites in the class docs).
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        // Clear any residual text from a previous turn so the prompt is entered cleanly.
        clearInput(input)
        app.typeText(prompt)

        let sendButton = app.buttons.matching(identifier: "concierge.sendButton").firstMatch
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5),
                      "[\(id)] turn \(turnIndex): send button missing — did the text enter the field?")

        let busy = app.otherElements.matching(identifier: "concierge.chatState.busy").firstMatch
        sendButton.tap()
        XCTAssertTrue(busy.waitForExistence(timeout: 10),
                      "[\(id)] turn \(turnIndex): chat never entered processing — was the message sent?")
        XCTAssertTrue(busy.waitForNonExistence(timeout: timeout),
                      "[\(id)] turn \(turnIndex): response did not render within \(Int(timeout))s")
    }

    /// Deletes any existing text in the input so the next prompt is typed into an empty field.
    private func clearInput(_ input: XCUIElement) {
        guard let current = input.value as? String, !current.isEmpty else { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        input.typeText(deletes)
    }

    // MARK: - Config-driven scroll actions

    /// Runs the turn's configured scroll actions in order. Observational and best-effort: each
    /// action is skipped if its target is missing/offscreen, and never fails the test (the
    /// measurement is already captured before any action runs).
    private func performActions(_ actions: [ScrollAction]) {
        for action in actions {
            let identifier = resolveTarget(action.target)
            let element = app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch
            guard element.waitForExistence(timeout: 3) else { continue }
            let settle = UInt32((action.settleMs ?? 200) * 1000)
            for _ in 0..<max(1, action.times ?? 1) {
                guard element.isHittable else { break }  // offscreen / behind keyboard → stop
                swipe(element, contentDirection: action.scroll)
                usleep(settle)
            }
        }
    }

    /// Maps a target keyword to an accessibility identifier (or passes through a literal id).
    private func resolveTarget(_ target: String?) -> String {
        switch (target ?? "conversation").lowercased() {
        case "conversation", "messages", "messagelist": return "concierge.messageList"
        case "cards", "carousel": return "concierge.cardCarousel"
        default: return target ?? "concierge.messageList"
        }
    }

    /// Performs a swipe in the gesture direction that scrolls content the requested way.
    /// content down → swipe up, content up → swipe down, content right → swipe left, etc.
    private func swipe(_ element: XCUIElement, contentDirection: String) {
        switch contentDirection.lowercased() {
        case "down":  element.swipeUp()
        case "up":    element.swipeDown()
        case "right": element.swipeLeft()
        case "left":  element.swipeRight()
        default:      break
        }
    }

    /// Default vertical scroll: a few swipes reliably reach the bottom of a long response.
    /// Observational only — called after the timeline has been captured.
    private func scrollConversationToEnd() {
        performActions([ScrollAction(scroll: "down", target: "conversation", times: 3, settleMs: 150)])
    }

    /// Horizontally pages/scrolls the product-card carousel so every card is surfaced.
    /// Works for both the paged TabView and the horizontal ScrollView carousel styles.
    /// Observational and best-effort: if the carousel is offscreen/not hittable it is skipped
    /// (never fails the test, since the measurement is already captured).
    private func scrollCardCarousel() {
        let carousel = app.descendants(matching: .any)
            .matching(identifier: "concierge.cardCarousel").firstMatch
        guard carousel.waitForExistence(timeout: 3) else { return }
        for _ in 0..<4 {
            // swipeLeft throws if the element's visible frame is empty (offscreen / behind the
            // keyboard), so only swipe while it is actually hittable.
            guard carousel.isHittable else { break }
            carousel.swipeLeft()
            usleep(300_000)  // brief settle between cards
        }
    }

    /// Reads the idle probe's timeline JSON, polling until a fresh snapshot (submitMs greater
    /// than the previous turn's) is published. Returns nil on timeout.
    private func readTimeline(after lastSubmitMs: Int64, timeout: TimeInterval) -> Timeline? {
        let idle = app.otherElements.matching(identifier: "concierge.chatState.idle").firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if idle.exists,
               let json = idle.value as? String, !json.isEmpty,
               let data = json.data(using: .utf8),
               let t = try? JSONDecoder().decode(Timeline.self, from: data),
               t.submitMs > lastSubmitMs {
                return t
            }
            usleep(150_000)  // 150ms
        }
        return nil
    }

    // MARK: - Scenarios file

    private func loadScenarios() throws -> ScenarioFile {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "scenarios", withExtension: "json") else {
            throw TestError.missingScenarios(bundlePath: bundle.bundlePath)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScenarioFile.self, from: data)
    }

    // MARK: - Reporting

    private func reportTurn(scenarioId: String, turnIndex: Int, prompt: String, timing t: Timeline) {
        let text = """
        ⏱ [\(scenarioId)] turn \(turnIndex): "\(prompt.truncated(to: 50))"
            TTFB \(ms(t.ttfbMs)) · chunks \(t.chunkCount) (\(t.inProgressCount) in-progress) \
        · COMPLETED@\(ms(t.completedStateMs - t.submitMs)) · stream \(ms(t.streamMs)) \
        · render+\(ms(t.renderAfterCompleteMs)) · total \(ms(t.totalMs)) \
        · cards \(t.cardCount) · empty \(t.responseEmpty) · textLen \(t.textLength) · msgs \(t.renderedMessageCount)
        """
        print(text)
        let attachment = XCTAttachment(string: text)
        attachment.name = "timing-\(scenarioId)-turn\(turnIndex)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Prints and attaches a consolidated, human-readable summary table. All values in ms.
    private func attachSummary(_ results: ScenarioResultsFile) {
        var lines: [String] = []
        lines.append("=== Render Timing Summary (all values in ms) ===")
        lines.append(
            pad("Scenario", 9) + pad("Turn", 5) + pad("Prompt", 34)
            + pad("TTFB", 10) + pad("Stream", 10) + pad("Render", 10) + pad("Total", 10)
            + pad("Cards", 6) + pad("Empty", 7) + pad("Msgs", 5)
        )
        for scenario in results.scenarios {
            for (index, t) in scenario.turns.enumerated() {
                lines.append(
                    pad(scenario.id, 9)
                    + pad("\(index + 1)", 5)
                    + pad(String(t.prompt.prefix(32)), 34)
                    + pad("\(t.ttfbMs)ms", 10)
                    + pad("\(t.streamMs)ms", 10)
                    + pad("\(t.renderAfterCompleteMs)ms", 10)   // render-after-complete
                    + pad("\(t.totalMs)ms", 10)
                    + pad("\(t.cardCount)", 6)
                    + pad("\(t.responseEmpty)", 7)
                    + pad("\(t.renderedMessageCount)", 5)
                )
            }
        }
        let text = lines.joined(separator: "\n")
        print(text)
        let attachment = XCTAttachment(string: text)
        attachment.name = "summary.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Left-justifies `s` to width `w` (single trailing space if already at/over width).
    private func pad(_ s: String, _ w: Int) -> String {
        s.count >= w ? s + " " : s + String(repeating: " ", count: w - s.count)
    }

    private func attachResults(_ results: ScenarioResultsFile) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(results),
              let json = String(data: data, encoding: .utf8) else { return }
        print("=== scenario-results.json ===\n\(json)")
        let attachment = XCTAttachment(string: json)
        attachment.name = "scenario-results.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func ms(_ value: Int64) -> String {
        "\(value)ms"
    }
}

// MARK: - Errors

private enum TestError: LocalizedError {
    case missingScenarios(bundlePath: String)

    var errorDescription: String? {
        switch self {
        case .missingScenarios(let path):
            return "scenarios.json not found in the test bundle (\(path)). "
                + "Add it to the ConciergeDemoAppUITests target (select the file ▸ File inspector ▸ "
                + "Target Membership ▸ tick ConciergeDemoAppUITests)."
        }
    }
}

// MARK: - Scenario input models (mirror scenarios.json)

private struct ScenarioFile: Codable {
    var responseTimeoutSeconds: Int?
    var scenarios: [Scenario]
}

private struct Scenario: Codable {
    var id: String
    var name: String
    var turns: [Turn]
}

private struct Turn: Codable {
    var prompt: String
    var stopWhen: StopCondition?
    /// Optional ordered scroll actions to run after the response loads. If omitted, the runner
    /// performs the default scroll (conversation to end + cards when present).
    var actions: [ScrollAction]?
}

/// A single config-driven scroll, e.g. `{ "scroll": "down", "target": "conversation", "times": 3 }`.
private struct ScrollAction: Codable {
    /// Content direction: "up" | "down" | "left" | "right".
    var scroll: String
    /// "conversation" → concierge.messageList; "cards"/"carousel" → concierge.cardCarousel;
    /// any other string is used as a literal accessibility identifier. Defaults to "conversation".
    var target: String?
    /// Number of swipes (default 1).
    var times: Int?
    /// Pause between swipes in milliseconds (default 200).
    var settleMs: Int?
}

/// All present keys must hold (logical AND). An empty object matches any result.
private struct StopCondition: Codable {
    var hasCards: Bool?
    var nonEmpty: Bool?
    var minMessages: Int?

    func matches(_ t: Timeline) -> Bool {
        if let hasCards = hasCards, (t.cardCount > 0) != hasCards { return false }
        if let nonEmpty = nonEmpty, (!t.responseEmpty) != nonEmpty { return false }
        if let minMessages = minMessages, t.renderedMessageCount < minMessages { return false }
        return true
    }
}

// MARK: - Result models

/// Mirrors the `TurnTiming` struct in the app (its serialized JSON keys).
private struct Timeline: Codable {
    let prompt: String
    let submitMs: Int64
    let firstChunkMs: Int64
    let completedStateMs: Int64
    let streamCompleteMs: Int64
    let renderCompleteMs: Int64
    let chunkCount: Int
    let inProgressCount: Int
    let renderedMessageCount: Int
    let cardCount: Int
    let responseEmpty: Bool
    let textLength: Int
    let ttfbMs: Int64
    let streamMs: Int64
    let renderAfterCompleteMs: Int64
    let totalMs: Int64
}

private struct ScenarioResultsFile: Codable {
    var scenarios: [ScenarioResult]
}

private struct ScenarioResult: Codable {
    var id: String
    var name: String
    var turns: [Timeline]
}

// MARK: - Helpers

private extension String {
    func truncated(to length: Int) -> String {
        count <= length ? self : String(prefix(length)) + "…"
    }
}
