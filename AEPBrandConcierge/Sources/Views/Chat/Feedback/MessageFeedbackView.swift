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

import SwiftUI

/// Standalone thumbs-up/down feedback row for an agent message.
/// Used when `thumbsPlacement` is `.standalone` or when there are no sources to host the thumbs.
struct MessageFeedbackView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackPresenter

    let feedbackSentiment: FeedbackSentiment?
    let messageId: UUID?

    var body: some View {
        HStack(spacing: theme.layout.feedbackContainerGap) {
            let iconButtonSize = theme.components.feedback.iconButtonSizeDesktop

            FeedbackIconButton(
                iconButtonSize: iconButtonSize,
                foregroundColor: thumbUpColor,
                normalBackgroundColor: theme.colors.feedback.iconButtonBackground.color,
                activeBackgroundColor: theme.colors.feedback.iconButtonBackground.color.opacity(0.85),
                isDisabled: feedbackSentiment != nil,
                accessibilityLabel: theme.text.feedbackThumbsUpAria,
                action: { feedbackPresenter.present(.positive, messageId) },
                label: { thumbUpImage }
            )

            FeedbackIconButton(
                iconButtonSize: iconButtonSize,
                foregroundColor: thumbDownColor,
                normalBackgroundColor: theme.colors.feedback.iconButtonBackground.color,
                activeBackgroundColor: theme.colors.feedback.iconButtonBackground.color.opacity(0.85),
                isDisabled: feedbackSentiment != nil,
                accessibilityLabel: theme.text.feedbackThumbsDownAria,
                action: { feedbackPresenter.present(.negative, messageId) },
                label: { thumbDownImage }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(theme.text.feedbackHelpfulLabel)
    }

    @ViewBuilder
    private var thumbUpImage: some View {
        if let uiImage = UIImage(named: "S2_Icon_ThumbUp_20_N") {
            Image(uiImage: uiImage).renderingMode(.template)
        } else {
            Image(systemName: "hand.thumbsup")
        }
    }

    @ViewBuilder
    private var thumbDownImage: some View {
        if let uiImage = UIImage(named: "S2_Icon_ThumbDown_20_N") {
            Image(uiImage: uiImage).renderingMode(.template)
        } else {
            Image(systemName: "hand.thumbsdown")
        }
    }

    private var thumbUpColor: Color {
        guard let sentiment = feedbackSentiment else {
            return theme.colors.message.conciergeText.color
        }
        return sentiment == .positive ? theme.colors.primary.primary.color : Color.gray.opacity(0.4)
    }

    private var thumbDownColor: Color {
        guard let sentiment = feedbackSentiment else {
            return theme.colors.message.conciergeText.color
        }
        return sentiment == .negative ? theme.colors.primary.primary.color : Color.gray.opacity(0.4)
    }
}

// MARK: - Previews
#Preview("No prior sentiment") {
    MessageFeedbackView(feedbackSentiment: nil, messageId: nil)
        .padding()
        .background(Color(UIColor.systemBackground))
}

#Preview("Positive submitted") {
    MessageFeedbackView(feedbackSentiment: .positive, messageId: nil)
        .padding()
        .background(Color(UIColor.systemBackground))
}
