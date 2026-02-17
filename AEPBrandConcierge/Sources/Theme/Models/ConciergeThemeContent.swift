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

import SwiftUI

/// Disclaimer configuration with text and links
public struct ConciergeDisclaimer: Codable {
    public var text: String
    public var links: [ConciergeDisclaimerLink]

    public init(
        text: String = "AI responses may be inaccurate. Check answers and sources. {Terms}",
        links: [ConciergeDisclaimerLink] = []
    ) {
        self.text = text
        self.links = links
    }
}

/// Disclaimer link configuration
public struct ConciergeDisclaimerLink: Codable {
    public var text: String
    public var url: String

    public init(text: String = "", url: String = "") {
        self.text = text
        self.url = url
    }
}

/// Welcome example card configuration
public struct ConciergeWelcomeExample: Codable {
    public var text: String
    public var image: String?
    public var backgroundColor: CodableColor?

    public init(text: String = "", image: String? = nil, backgroundColor: CodableColor? = nil) {
        self.text = text
        self.image = image
        self.backgroundColor = backgroundColor
    }
}

/// Text content and copy configuration (localizable strings)
/// Maps from web config "text" object with dot-notation keys (ex: "welcome.heading")
public struct ConciergeCopy: Codable {
    public var welcomeHeading: String
    public var welcomeSubheading: String
    public var inputPlaceholder: String
    public var inputMessageInputAria: String
    public var inputSendAria: String
    public var inputAiChatIconTooltip: String
    public var inputMicAria: String
    public var cardAriaSelect: String
    public var carouselPrevAria: String
    public var carouselNextAria: String
    public var scrollBottomAria: String
    public var errorNetwork: String
    public var loadingMessage: String
    public var feedbackDialogTitlePositive: String
    public var feedbackDialogTitleNegative: String
    public var feedbackDialogQuestionPositive: String
    public var feedbackDialogQuestionNegative: String
    public var feedbackDialogNotes: String
    public var feedbackDialogSubmit: String
    public var feedbackDialogCancel: String
    public var feedbackDialogNotesPlaceholder: String
    public var feedbackToastSuccess: String
    public var feedbackThumbsUpAria: String
    public var feedbackThumbsDownAria: String

    enum CodingKeys: String, CodingKey {
        case welcomeHeading = "welcome.heading"
        case welcomeSubheading = "welcome.subheading"
        case inputPlaceholder = "input.placeholder"
        case inputMessageInputAria = "input.messageInput.aria"
        case inputSendAria = "input.send.aria"
        case inputAiChatIconTooltip = "input.aiChatIcon.tooltip"
        case inputMicAria = "input.mic.aria"
        case cardAriaSelect = "card.aria.select"
        case carouselPrevAria = "carousel.prev.aria"
        case carouselNextAria = "carousel.next.aria"
        case scrollBottomAria = "scroll.bottom.aria"
        case errorNetwork = "error.network"
        case loadingMessage = "loading.message"
        case feedbackDialogTitlePositive = "feedback.dialog.title.positive"
        case feedbackDialogTitleNegative = "feedback.dialog.title.negative"
        case feedbackDialogQuestionPositive = "feedback.dialog.question.positive"
        case feedbackDialogQuestionNegative = "feedback.dialog.question.negative"
        case feedbackDialogNotes = "feedback.dialog.notes"
        case feedbackDialogSubmit = "feedback.dialog.submit"
        case feedbackDialogCancel = "feedback.dialog.cancel"
        case feedbackDialogNotesPlaceholder = "feedback.dialog.notes.placeholder"
        case feedbackToastSuccess = "feedback.toast.success"
        case feedbackThumbsUpAria = "feedback.thumbsUp.aria"
        case feedbackThumbsDownAria = "feedback.thumbsDown.aria"
    }

    public init(
        welcomeHeading: String = "Explore what you can do with Adobe apps.",
        welcomeSubheading: String = "Choose an option or tell us what interests you and we'll point you in the right direction.",
        inputPlaceholder: String = "Tell us what you'd like to do or create",
        inputMessageInputAria: String = "Message input",
        inputSendAria: String = "Send message",
        inputAiChatIconTooltip: String = "Ask AI",
        inputMicAria: String = "Voice input",
        cardAriaSelect: String = "Select example message",
        carouselPrevAria: String = "Previous cards",
        carouselNextAria: String = "Next cards",
        scrollBottomAria: String = "Scroll to bottom",
        errorNetwork: String = "I'm sorry, I'm having trouble connecting to our services right now.",
        loadingMessage: String = "Generating response from our knowledge base",
        feedbackDialogTitlePositive: String = "Your feedback is appreciated",
        feedbackDialogTitleNegative: String = "Your feedback is appreciated",
        feedbackDialogQuestionPositive: String = "What went well? Select all that apply.",
        feedbackDialogQuestionNegative: String = "What went wrong? Select all that apply.",
        feedbackDialogNotes: String = "Notes",
        feedbackDialogSubmit: String = "Submit",
        feedbackDialogCancel: String = "Cancel",
        feedbackDialogNotesPlaceholder: String = "Additional notes (optional)",
        feedbackToastSuccess: String = "Thank you for the feedback.",
        feedbackThumbsUpAria: String = "Thumbs up",
        feedbackThumbsDownAria: String = "Thumbs down"
    ) {
        self.welcomeHeading = welcomeHeading
        self.welcomeSubheading = welcomeSubheading
        self.inputPlaceholder = inputPlaceholder
        self.inputMessageInputAria = inputMessageInputAria
        self.inputSendAria = inputSendAria
        self.inputAiChatIconTooltip = inputAiChatIconTooltip
        self.inputMicAria = inputMicAria
        self.cardAriaSelect = cardAriaSelect
        self.carouselPrevAria = carouselPrevAria
        self.carouselNextAria = carouselNextAria
        self.scrollBottomAria = scrollBottomAria
        self.errorNetwork = errorNetwork
        self.loadingMessage = loadingMessage
        self.feedbackDialogTitlePositive = feedbackDialogTitlePositive
        self.feedbackDialogTitleNegative = feedbackDialogTitleNegative
        self.feedbackDialogQuestionPositive = feedbackDialogQuestionPositive
        self.feedbackDialogQuestionNegative = feedbackDialogQuestionNegative
        self.feedbackDialogNotes = feedbackDialogNotes
        self.feedbackDialogSubmit = feedbackDialogSubmit
        self.feedbackDialogCancel = feedbackDialogCancel
        self.feedbackDialogNotesPlaceholder = feedbackDialogNotesPlaceholder
        self.feedbackToastSuccess = feedbackToastSuccess
        self.feedbackThumbsUpAria = feedbackThumbsUpAria
        self.feedbackThumbsDownAria = feedbackThumbsDownAria
    }
}

/// Arrays configuration (welcome examples, feedback options)
public struct ConciergeArrays: Codable {
    public var welcomeExamples: [ConciergeWelcomeExample]
    public var feedbackPositiveOptions: [String]
    public var feedbackNegativeOptions: [String]

    private enum DotKeys: String, CodingKey {
        case welcomeExamples = "welcome.examples"
        case feedbackPositiveOptions = "feedback.positive.options"
        case feedbackNegativeOptions = "feedback.negative.options"
    }

    public static let defaultPositive: [String] = [
        "Helpful and relevant recommendations",
        "Clear and easy to understand",
        "Friendly and conversational tone",
        "Visually appealing presentation",
        "Other"
    ]

    public static let defaultNegative: [String] = [
        "Didn't understand my request",
        "Unhelpful or irrelevant information",
        "Too vague or lacking detail",
        "Errors or poor quality response",
        "Other"
    ]

    public init(
        welcomeExamples: [ConciergeWelcomeExample] = [],
        feedbackPositiveOptions: [String] = ConciergeArrays.defaultPositive,
        feedbackNegativeOptions: [String] = ConciergeArrays.defaultNegative
    ) {
        self.welcomeExamples = welcomeExamples
        self.feedbackPositiveOptions = feedbackPositiveOptions
        self.feedbackNegativeOptions = feedbackNegativeOptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DotKeys.self)
        welcomeExamples = try container.decodeIfPresent([ConciergeWelcomeExample].self, forKey: .welcomeExamples) ?? []
        feedbackPositiveOptions = try container.decodeIfPresent([String].self, forKey: .feedbackPositiveOptions) ?? ConciergeArrays.defaultPositive
        feedbackNegativeOptions = try container.decodeIfPresent([String].self, forKey: .feedbackNegativeOptions) ?? ConciergeArrays.defaultNegative
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DotKeys.self)
        try container.encode(welcomeExamples, forKey: .welcomeExamples)
        try container.encode(feedbackPositiveOptions, forKey: .feedbackPositiveOptions)
        try container.encode(feedbackNegativeOptions, forKey: .feedbackNegativeOptions)
    }
}
