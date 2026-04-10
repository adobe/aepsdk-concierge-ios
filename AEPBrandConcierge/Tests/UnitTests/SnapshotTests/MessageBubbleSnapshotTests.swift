/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import SnapshotTesting
import SwiftUI
import XCTest

@testable import AEPBrandConcierge

final class MessageBubbleSnapshotTests: XCTestCase {
    func test_messageBubbleProbe_defaultTheme() {
        let view = MessageBubbleProbeHost(theme: ConciergeThemeLoader.default())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 320)))
    }
    
    func test_messageBubbleProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()

        // Exaggerate bubble styling so wiring issues are obvious.
        probeTheme.colors.message.userBackground = CodableColor(.yellow)
        probeTheme.colors.message.userText = CodableColor(.black)

        probeTheme.colors.message.conciergeBackground = CodableColor(.purple)
        probeTheme.colors.message.conciergeText = CodableColor(.white)

        probeTheme.layout.messagePadding = ConciergePadding(vertical: 24, horizontal: 30)
        probeTheme.layout.messageBorderRadius = 28

        // Sibling control for bubbles: cap width so the change is visible and stable.
        probeTheme.layout.messageMaxWidth = 260

        let view = MessageBubbleProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 320)))
    }

    // MARK: - Agent Icon Layout Tests

    func test_messageBubbleProbe_agentIconLayout() {
        var probeTheme = ConciergeThemeLoader.default()
        // Non-empty path activates icon layout mode (asymmetric padding + icon slot).
        // The asset won't load at test time; the test captures the padding/spacing geometry.
        probeTheme.assets.icons.company = "agent-icon"

        let view = MessageBubbleAgentIconProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 160)))
    }

    func test_messageBubbleProbe_agentIconLayout_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.assets.icons.company = "agent-icon"

        // Exaggerate colors and icon dimensions so wiring issues are obvious.
        probeTheme.colors.message.conciergeBackground = CodableColor(.orange)
        probeTheme.colors.message.conciergeText = CodableColor(.black)
        probeTheme.layout.agentIconSize = 50
        probeTheme.layout.agentIconSpacing = 20

        let view = MessageBubbleAgentIconProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }

    // MARK: - Sources + Agent Icon Alignment Tests

    func test_agentMessage_sourcesAlignWithText_withAgentIcon() {
        var probeTheme = ConciergeThemeLoader.default()
        // Non-empty path activates icon layout mode; sources should indent to align with agent text.
        probeTheme.assets.icons.company = "agent-icon"

        let view = AgentMessageWithSourcesProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 160)))
    }

    func test_agentMessage_sourcesAlignWithText_noAgentIcon() {
        // Without an icon the sources row should sit at the default message leading edge.
        let view = AgentMessageWithSourcesProbeHost(theme: ConciergeThemeLoader.default())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 120)))
    }

    // MARK: - Prompt Suggestion Alignment Tests

    func test_promptSuggestion_alignsWithAgentText_withAgentIcon() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.assets.icons.company = "agent-icon"

        let view = PromptSuggestionAlignmentProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 240)))
    }

    // MARK: - Response Placeholder Leading Padding Tests

    func test_responsePlaceholder_defaultLeadingPadding() {
        let view = ResponsePlaceholderProbeHost(
            leadingPadding: ConciergeResponsePlaceholderView.defaultHorizontalPadding,
            theme: ConciergeThemeLoader.default()
        )
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }

    func test_responsePlaceholder_zeroLeadingPadding() {
        // Simulates the icon layout mode where the agent icon provides the visual inset,
        // so the placeholder uses zero leading padding.
        let view = ResponsePlaceholderProbeHost(
            leadingPadding: 0,
            theme: ConciergeThemeLoader.default()
        )
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 80)))
    }
}

private struct MessageBubbleProbeHost: View {
    let theme: ConciergeTheme

    var body: some View {
        VStack(spacing: 16) {
            ChatMessageView(
                template: .basic(isUserMessage: true),
                messageBody: "User message bubble with a bit of text."
            )

            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: "Agent message bubble with a bit of text."
            )

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 390, height: 320, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}

/// Probe for agent icon layout: a settled bubble and a loading placeholder, both in icon layout mode.
private struct MessageBubbleAgentIconProbeHost: View {
    let theme: ConciergeTheme

    var body: some View {
        VStack(spacing: 12) {
            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: "Agent response rendered in icon layout mode."
            )
            // nil body renders the loading placeholder, also in icon layout mode.
            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: nil
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: 390, height: 160, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}

/// Probe for sources + agent icon alignment: an agent bubble with sources attached.
/// The sources row should indent to align with the start of the agent response text.
private struct AgentMessageWithSourcesProbeHost: View {
    let theme: ConciergeTheme

    private let sources: [Source] = [
        Source(url: "https://example.com/1", title: "A source", startIndex: 1, endIndex: 2, citationNumber: 1)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: "Agent response with a source attached.",
                sources: sources
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: 390, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}

/// Probe for prompt suggestion alignment: an agent bubble followed by a prompt suggestion pill.
/// The pill leading edge should align with the agent response text (not the icon).
private struct PromptSuggestionAlignmentProbeHost: View {
    let theme: ConciergeTheme

    var body: some View {
        VStack(spacing: 12) {
            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: "Which option interests you most?"
            )
            ChatMessageView(
                template: .promptSuggestion(text: "Tell me more about option A")
            )
            ChatMessageView(
                template: .promptSuggestion(text: "Show me something else")
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: 390, height: 240, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}

/// Probe for isolated ConciergeResponsePlaceholderView leading-padding variants.
private struct ResponsePlaceholderProbeHost: View {
    let leadingPadding: CGFloat
    let theme: ConciergeTheme

    var body: some View {
        HStack(alignment: .top) {
            ConciergeResponsePlaceholderView(leadingPadding: leadingPadding)
            Spacer()
        }
        .padding(16)
        .frame(width: 390, height: 80, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}
