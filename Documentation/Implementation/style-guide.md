# AEPBrandConcierge Style Guide

This document provides a comprehensive reference for all styling properties supported by the AEPBrandConcierge framework. Themes are configured using JSON files that follow a web-compatible CSS variable format.

## Table of Contents

- [Overview](#overview)
- [JSON Structure](#json-structure)
- [Value Formats](#value-formats)
- [Metadata](#metadata)
- [Behavior](#behavior)
- [Disclaimer](#disclaimer)
- [Text (Copy)](#text-copy)
- [Arrays](#arrays)
- [Assets](#assets)
- [Theme Tokens](#theme-tokens)
  - [Typography](#typography)
  - [Colors](#colors)
  - [Layout](#layout)
- [Implementation Status](#implementation-status)

---

## Overview

The theme configuration is loaded from a JSON file using `ConciergeThemeLoader.load(from:in:)`. The framework supports CSS-like variable names (prefixed with `--`) that are automatically mapped to native Swift properties.

### Loading a Theme

```swift
// Load from app bundle
let theme = ConciergeThemeLoader.load(from: "theme-default", in: .main)

// Use default theme
let defaultTheme = ConciergeThemeLoader.default()
```

### Applying a Theme

Apply the theme using the `.conciergeTheme()` view modifier on your wrapped content:

```swift
import SwiftUI
import AEPBrandConcierge

struct ContentView: View {
    @State private var theme: ConciergeTheme = ConciergeThemeLoader.default()
    
    var body: some View {
        Concierge.wrap(
            // Your app content here
            Text("Hello, World!"),
            surfaces: ["my-surface"]
        )
        .conciergeTheme(theme)  // Apply theme to the wrapper
        .onAppear {
            // Load custom theme from JSON file
            if let loadedTheme = ConciergeThemeLoader.load(from: "my-theme", in: .main) {
                theme = loadedTheme
            }
        }
    }
}
```

> **Important:** The `.conciergeTheme()` modifier must be applied to the result of `Concierge.wrap()` so the theme is available to both the wrapper and the chat overlay.

---

## JSON Structure

The theme JSON file contains these top-level keys:

| Key | Description |
|-----|-------------|
| `metadata` | Theme identification and versioning |
| `behavior` | Feature toggles and interaction settings |
| `disclaimer` | Legal/disclaimer text configuration |
| `text` | Localized UI strings (copy) |
| `arrays` | Welcome examples and feedback options |
| `assets` | Icon and image assets |
| `theme` | Visual styling tokens (CSS variables) |

---

## Value Formats

Understanding the value formats used throughout this document.

### Colors

Colors are specified as hex strings:

```json
"--color-primary": "#EB1000"
"--message-user-background": "#EBEEFF"
"--input-box-shadow": "0 2px 8px 0 #00000014"
```

Supported formats:
- `#RRGGBB` - 6 digit hex
- `#RRGGBBAA` - 8 digit hex with alpha

### Dimensions

Dimensions use CSS pixel units:

```json
"--input-height": "52px"
"--input-border-radius": "12px"
"--message-max-width": "100%"
```

### Padding

Padding follows CSS shorthand syntax:

```json
"--message-padding": "8px 16px"
```

Formats:
- `8px` - All sides
- `8px 16px` - Vertical, horizontal
- `8px 16px 4px` - Top, horizontal, bottom
- `8px 16px 4px 2px` - Top, right, bottom, left

### Shadows

Shadows use CSS box-shadow syntax:

```json
"--input-box-shadow": "0 2px 8px 0 #00000014"
"--multimodal-card-box-shadow": "none"
```

Format: `offsetX offsetY blurRadius spreadRadius color`

### Font Weights

Font weights use CSS numeric or named values:

| Value | Name |
|-------|------|
| `100` | `ultraLight` |
| `200` | `thin` |
| `300` | `light` |
| `400` / `normal` | `regular` |
| `500` | `medium` |
| `600` | `semibold` |
| `700` / `bold` | `bold` |
| `800` | `heavy` |
| `900` | `black` |

### Text Alignment

| Value | SwiftUI Equivalent |
|-------|-------------------|
| `left` | `.leading` |
| `center` | `.center` |
| `right` | `.trailing` |

---

## Metadata

Theme identification information.

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `metadata.brandName` | `String` | `""` | Brand/company name |
| `metadata.version` | `String` | `"0.0.0"` | Theme version |
| `metadata.language` | `String` | `"en-US"` | Locale identifier |
| `metadata.namespace` | `String` | `"brand-concierge"` | Theme namespace |

### Example

```json
{
  "metadata": {
    "brandName": "Concierge Demo",
    "version": "1.0.0",
    "language": "en-US",
    "namespace": "brand-concierge"
  }
}
```

---

## Behavior

Feature toggles and interaction configuration.

### Multimodal Carousel

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `behavior.multimodalCarousel.cardClickAction` | `String` | `"openLink"` | Action when carousel card is tapped. Currently "openLink" is the only option available. |

### Input

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `behavior.input.enableVoiceInput` | `Bool` | `false` | Enable voice input button |
| `behavior.input.disableMultiline` | `Bool` | `true` | Disable multiline text input |
| `behavior.input.showAiChatIcon` | `Object?` | `null` | AI chat icon configuration |

### Chat

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `behavior.chat.messageAlignment` | `String` | `"left"` | Message alignment (`"left"`, `"center"`, `"right"`) |
| `behavior.chat.messageWidth` | `String` | `"100%"` | Max message width (e.g., `"100%"`, `"768px"`) |

### Privacy Notice

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `behavior.privacyNotice.title` | `String` | `"Privacy Notice"` | Privacy dialog title |
| `behavior.privacyNotice.text` | `String` | `"Privacy notice text."` | Privacy notice content |

### Example

```json
{
  "behavior": {
    "multimodalCarousel": {
      "cardClickAction": "openLink"
    },
    "input": {
      "enableVoiceInput": true,
      "disableMultiline": false,
      "showAiChatIcon": null
    },
    "chat": {
      "messageAlignment": "left",
      "messageWidth": "100%"
    },
    "privacyNotice": {
      "title": "Privacy Notice",
      "text": "Privacy notice text."
    }
  }
}
```

---

## Disclaimer

Legal disclaimer text with embedded links.

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `disclaimer.text` | `String` | `"AI responses may be inaccurate..."` | Disclaimer text with `{placeholders}` for links |
| `disclaimer.links` | `Array` | `[]` | Array of link objects |
| `disclaimer.links[].text` | `String` | `""` | Link display text (matches placeholder) |
| `disclaimer.links[].url` | `String` | `""` | Link URL |

### Example

```json
{
  "disclaimer": {
    "text": "AI responses may be inaccurate. Check answers and sources. {Terms}",
    "links": [
      {
        "text": "Terms",
        "url": "https://www.adobe.com/legal/licenses-terms/adobe-gen-ai-user-guidelines.html"
      }
    ]
  }
}
```

---

## Text (Copy)

Localized UI strings using dot-notation keys.

### ✅ Content Recommendations

While there are no strict requirements for character limits in many of these text fields, it is **_strongly_** recommended that the values be tested on target device(s) prior to deployment, ensuring the UI renders as desired.

### Welcome Screen

| JSON Key | Default | Description |
|----------|---------|-------------|
| `text["welcome.heading"]` | `"Explore what you can do with Adobe apps."` | Welcome screen heading |
| `text["welcome.subheading"]` | `"Choose an option or tell us..."` | Welcome screen subheading |

### Input

| JSON Key | Default | Description |
|----------|---------|-------------|
| `text["input.placeholder"]` | `"Tell us what you'd like to do or create"` | Input field placeholder |
| `text["input.messageInput.aria"]` | `"Message input"` | Accessibility label for input |
| `text["input.send.aria"]` | `"Send message"` | Accessibility label for send button |
| `text["input.aiChatIcon.tooltip"]` | `"Ask AI"` | AI icon tooltip |
| `text["input.mic.aria"]` | `"Voice input"` | Accessibility label for mic button |

### Cards & Carousel

| JSON Key | Default | Description |
|----------|---------|-------------|
| `text["card.aria.select"]` | `"Select example message"` | Card selection accessibility |
| `text["carousel.prev.aria"]` | `"Previous cards"` | Previous button accessibility |
| `text["carousel.next.aria"]` | `"Next cards"` | Next button accessibility |

### System Messages

| JSON Key | Default | Description |
|----------|---------|-------------|
| `text["scroll.bottom.aria"]` | `"Scroll to bottom"` | Scroll button accessibility |
| `text["error.network"]` | `"I'm sorry, I'm having trouble..."` | Network error message |
| `text["loading.message"]` | `"Generating response from our knowledge base"` | Loading indicator text |

### Feedback Dialog

| JSON Key | Default | Description |
|----------|---------|-------------|
| `text["feedback.dialog.title.positive"]` | `"Your feedback is appreciated"` | Positive feedback dialog title |
| `text["feedback.dialog.title.negative"]` | `"Your feedback is appreciated"` | Negative feedback dialog title |
| `text["feedback.dialog.question.positive"]` | `"What went well? Select all that apply."` | Positive feedback question |
| `text["feedback.dialog.question.negative"]` | `"What went wrong? Select all that apply."` | Negative feedback question |
| `text["feedback.dialog.notes"]` | `"Notes"` | Notes section label |
| `text["feedback.dialog.submit"]` | `"Submit"` | Submit button text |
| `text["feedback.dialog.cancel"]` | `"Cancel"` | Cancel button text |
| `text["feedback.dialog.notes.placeholder"]` | `"Additional notes (optional)"` | Notes placeholder |
| `text["feedback.toast.success"]` | `"Thank you for the feedback."` | Success toast message |
| `text["feedback.thumbsUp.aria"]` | `"Thumbs up"` | Thumbs up accessibility |
| `text["feedback.thumbsDown.aria"]` | `"Thumbs down"` | Thumbs down accessibility |

### Example

```json
{
  "text": {
    "welcome.heading": "Welcome to Brand Concierge!",
    "welcome.subheading": "I'm your personal guide to help you explore.",
    "input.placeholder": "How can I help?",
    "error.network": "I'm sorry, I'm having trouble connecting."
  }
}
```

---

## Arrays

List-based configuration for examples and feedback options.

### Welcome Examples

> It is recommended to have no more than four items in your provided welcome examples.
>
> Always test your values on device to ensure the UI looks as desired.

| JSON Key | Type | Description |
|----------|------|-------------|
| `arrays["welcome.examples"]` | `Array` | Welcome screen example cards |
| `arrays["welcome.examples"][].text` | `String` | Card display text |
| `arrays["welcome.examples"][].image` | `String?` | Card image URL |
| `arrays["welcome.examples"][].backgroundColor` | `String?` | Card background color (hex) |

### Feedback Options

> It is recommended to have no more than five options available for feedback. 
>
> Always test your values on device to ensure the UI looks as desired.

| JSON Key | Type | Description |
|----------|------|-------------|
| `arrays["feedback.positive.options"]` | `Array<String>` | Positive feedback checkbox options |
| `arrays["feedback.negative.options"]` | `Array<String>` | Negative feedback checkbox options |

### Example

```json
{
  "arrays": {
    "welcome.examples": [
      {
        "text": "I'd like to explore templates to see what I can create.",
        "image": "https://example.com/template.png",
        "backgroundColor": "#F5F5F5"
      }
    ],
    "feedback.positive.options": [
      "Helpful and relevant recommendations",
      "Clear and easy to understand",
      "Other"
    ],
    "feedback.negative.options": [
      "Didn't understand my request",
      "Unhelpful or irrelevant information",
      "Other"
    ]
  }
}
```

---

## Assets

Icon and image asset configuration.

| JSON Key | Type | Default | Description |
|----------|------|---------|-------------|
| `assets.icons.company` | `String` | `""` | Company logo (SVG string or URL) |

### Example

```json
{
  "assets": {
    "icons": {
      "company": ""
    }
  }
}
```

---

## Theme Tokens

Visual styling using CSS-like variable names. All properties in the `theme` object use the `--property-name` format.

### Typography

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--font-family` | `typography.fontFamily` | `String` | `""` (system font) | Font family name |
| `--line-height-body` | `typography.lineHeight` | `CGFloat` | `1.0` | Line height multiplier |

### Colors - Primary

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--color-primary` | `colors.primary.primary` | `Color` | `accentColor` | Primary brand color |
| `--color-text` | `colors.primary.text` | `Color` | `primary` | Primary text color |

### Colors - Surface

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--main-container-background` | `colors.surface.mainContainerBackground` | `Color` | `systemBackground` | Main container background |
| `--main-container-bottom-background` | `colors.surface.mainContainerBottomBackground` | `Color` | `systemBackground` | Bottom container background |
| `--message-blocker-background` | `colors.surface.messageBlockerBackground` | `Color` | `systemBackground` | Message blocker overlay |

### Colors - Messages

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--message-user-background` | `colors.message.userBackground` | `Color` | `secondarySystemBackground` | User message bubble background |
| `--message-user-text` | `colors.message.userText` | `Color` | `primary` | User message text color |
| `--message-concierge-background` | `colors.message.conciergeBackground` | `Color` | `systemBackground` | AI message bubble background |
| `--message-concierge-text` | `colors.message.conciergeText` | `Color` | `primary` | AI message text color |
| `--message-concierge-link-color` | `colors.message.conciergeLink` | `Color` | `accentColor` | Link color in AI messages |

### Colors - Buttons

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--button-primary-background` | `colors.button.primaryBackground` | `Color` | `accentColor` | Primary button background |
| `--button-primary-text` | `colors.button.primaryText` | `Color` | `white` | Primary button text |
| `--button-secondary-border` | `colors.button.secondaryBorder` | `Color` | `primary` | Secondary button border |
| `--button-secondary-text` | `colors.button.secondaryText` | `Color` | `primary` | Secondary button text |
| `--submit-button-fill-color` | `colors.button.submitFill` | `Color` | `clear` | Submit button fill |
| `--submit-button-fill-color-disabled` | `colors.button.submitFillDisabled` | `Color` | `clear` | Disabled submit button fill |
| `--color-button-submit` | `colors.button.submitText` | `Color` | `accentColor` | Submit button icon/text color |
| `--button-disabled-background` | `colors.button.disabledBackground` | `Color` | `clear` | Disabled button background |

### Colors - Input

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--input-background` | `colors.input.background` | `Color` | `white` | Input field background |
| `--input-text-color` | `colors.input.text` | `Color` | `primary` | Input text color |
| `--input-outline-color` | `colors.input.outline` | `Color?` | `nil` | Input border color |
| `--input-focus-outline-color` | `colors.input.outlineFocus` | `Color` | `accentColor` | Focused input border color |

### Colors - Citations

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--citations-background-color` | `colors.citation.background` | `Color` | `systemGray3` | Citation pill background |
| `--citations-text-color` | `colors.citation.text` | `Color` | `primary` | Citation text color |

### Colors - Feedback

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--feedback-icon-btn-background` | `colors.feedback.iconButtonBackground` | `Color` | `clear` | Feedback button background |

### Colors - Disclaimer

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--disclaimer-color` | `colors.disclaimer` | `Color` | `systemGray` | Disclaimer text color |

### Layout - Input

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--input-height-mobile` | `layout.inputHeight` | `CGFloat` | `52` | Input field height |
| `--input-border-radius-mobile` | `layout.inputBorderRadius` | `CGFloat` | `12` | Input field corner radius |
| `--input-outline-width` | `layout.inputOutlineWidth` | `CGFloat` | `2` | Input border width |
| `--input-focus-outline-width` | `layout.inputFocusOutlineWidth` | `CGFloat` | `2` | Focused input border width |
| `--input-font-size` | `layout.inputFontSize` | `CGFloat` | `16` | Input text font size |
| `--input-button-height` | `layout.inputButtonHeight` | `CGFloat` | `30` | Input button height |
| `--input-button-width` | `layout.inputButtonWidth` | `CGFloat` | `30` | Input button width |
| `--input-button-border-radius` | `layout.inputButtonBorderRadius` | `CGFloat` | `8` | Input button corner radius |
| `--input-box-shadow` | `layout.inputBoxShadow` | `Shadow` | `none` | Input field shadow |

### Layout - Messages

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--message-border-radius` | `layout.messageBorderRadius` | `CGFloat` | `10` | Message bubble corner radius |
| `--message-padding` | `layout.messagePadding` | `Padding` | `8px 16px` | Message content padding |
| `--message-max-width` | `layout.messageMaxWidth` | `CGFloat?` | `nil` | Max message width |

### Layout - Chat

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--chat-interface-max-width` | `layout.chatInterfaceMaxWidth` | `CGFloat` | `768` | Max chat interface width |
| `--chat-history-padding` | `layout.chatHistoryPadding` | `CGFloat` | `16` | Chat history horizontal padding |
| `--chat-history-padding-top-expanded` | `layout.chatHistoryPaddingTopExpanded` | `CGFloat` | `8` | Top padding when expanded |
| `--chat-history-bottom-padding` | `layout.chatHistoryBottomPadding` | `CGFloat` | `12` | Bottom padding |
| `--message-blocker-height` | `layout.messageBlockerHeight` | `CGFloat` | `105` | Message blocker overlay height |

### Layout - Cards & Carousel

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--border-radius-card` | `layout.borderRadiusCard` | `CGFloat` | `16` | Card corner radius |
| `--multimodal-card-box-shadow` | `layout.multimodalCardBoxShadow` | `Shadow` | `0 2px 8px...` | Card shadow |

### Layout - Buttons

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--button-height-s` | `layout.buttonHeightSmall` | `CGFloat` | `30` | Small button height |

### Layout - Feedback

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--feedback-container-gap` | `layout.feedbackContainerGap` | `CGFloat` | `4` | Gap between feedback buttons |
| `--feedback-icon-btn-size-desktop` | `layout.feedbackIconButtonSize` | `CGFloat` | `44` | Feedback button hit target size |

### Layout - Citations

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--citations-text-font-weight` | `layout.citationsTextFontWeight` | `FontWeight` | `bold` | Citation text weight |
| `--citations-desktop-button-font-size` | `layout.citationsDesktopButtonFontSize` | `CGFloat` | `14` | Citation button font size |

### Layout - Disclaimer

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--disclaimer-font-size` | `layout.disclaimerFontSize` | `CGFloat` | `12` | Disclaimer font size |
| `--disclaimer-font-weight` | `layout.disclaimerFontWeight` | `FontWeight` | `regular` | Disclaimer font weight |

### Layout - Welcome Screen Order

| CSS Variable | Swift Property | Type | Default | Description |
|--------------|----------------|------|---------|-------------|
| `--welcome-input-order` | `layout.welcomeInputOrder` | `Int` | `3` | Input field display order |
| `--welcome-cards-order` | `layout.welcomeCardsOrder` | `Int` | `2` | Example cards display order |

---

## Complete Example

```json
{
  "metadata": {
    "brandName": "Concierge Demo",
    "version": "1.0.0",
    "language": "en-US",
    "namespace": "brand-concierge"
  },
  "behavior": {
    "multimodalCarousel": {
      "cardClickAction": "openLink"
    },
    "input": {
      "enableVoiceInput": true,
      "disableMultiline": false,
      "showAiChatIcon": null
    },
    "chat": {
      "messageAlignment": "left",
      "messageWidth": "100%"
    },
    "privacyNotice": {
      "title": "Privacy Notice",
      "text": "Privacy notice text."
    }
  },
  "disclaimer": {
    "text": "AI responses may be inaccurate. Check answers and sources. {Terms}",
    "links": [
      {
        "text": "Terms",
        "url": "https://www.adobe.com/legal/licenses-terms/adobe-gen-ai-user-guidelines.html"
      }
    ]
  },
  "text": {
    "welcome.heading": "Welcome to Brand Concierge!",
    "welcome.subheading": "I'm your personal guide to help you explore.",
    "input.placeholder": "How can I help?",
    "input.messageInput.aria": "Message input",
    "input.send.aria": "Send message",
    "feedback.dialog.title.positive": "Your feedback is appreciated",
    "feedback.dialog.submit": "Submit",
    "feedback.dialog.cancel": "Cancel"
  },
  "arrays": {
    "welcome.examples": [
      {
        "text": "I'd like to explore templates to see what I can create.",
        "image": "https://example.com/template.png",
        "backgroundColor": "#F5F5F5"
      }
    ],
    "feedback.positive.options": [
      "Helpful and relevant recommendations",
      "Clear and easy to understand",
      "Other"
    ],
    "feedback.negative.options": [
      "Didn't understand my request",
      "Unhelpful or irrelevant information",
      "Other"
    ]
  },
  "assets": {
    "icons": {
      "company": ""
    }
  },
  "theme": {
    "--welcome-input-order": "3",
    "--welcome-cards-order": "2",
    "--font-family": "",
    "--color-primary": "#EB1000",
    "--color-text": "#131313",
    "--line-height-body": "1.75",
    "--main-container-background": "#FFFFFF",
    "--main-container-bottom-background": "#FFFFFF",
    "--message-blocker-background": "#FFFFFF",
    "--input-height-mobile": "52px",
    "--input-border-radius-mobile": "12px",
    "--input-background": "#FFFFFF",
    "--input-outline-color": null,
    "--input-outline-width": "2px",
    "--input-focus-outline-width": "2px",
    "--input-focus-outline-color": "#4B75FF",
    "--input-font-size": "16px",
    "--input-text-color": "#292929",
    "--input-button-height": "32px",
    "--input-button-width": "32px",
    "--input-button-border-radius": "8px",
    "--input-box-shadow": "0 2px 8px 0 #00000014",
    "--submit-button-fill-color": "#FFFFFF",
    "--submit-button-fill-color-disabled": "#C6C6C6",
    "--color-button-submit": "#292929",
    "--button-disabled-background": "#FFFFFF",
    "--button-primary-background": "#3B63FB",
    "--button-primary-text": "#FFFFFF",
    "--button-secondary-border": "#2C2C2C",
    "--button-secondary-text": "#2C2C2C",
    "--button-height-s": "30px",
    "--disclaimer-color": "#4B4B4B",
    "--disclaimer-font-size": "12px",
    "--disclaimer-font-weight": "400",
    "--message-user-background": "#EBEEFF",
    "--message-user-text": "#292929",
    "--message-concierge-background": "#F5F5F5",
    "--message-concierge-text": "#292929",
    "--message-concierge-link-color": "#274DEA",
    "--message-border-radius": "10px",
    "--message-padding": "8px 16px",
    "--message-max-width": "100%",
    "--chat-interface-max-width": "768px",
    "--chat-history-padding": "16px",
    "--chat-history-padding-top-expanded": "0",
    "--chat-history-bottom-padding": "0",
    "--message-blocker-height": "105px",
    "--border-radius-card": "16px",
    "--multimodal-card-box-shadow": "none",
    "--feedback-container-gap": "4px",
    "--feedback-icon-btn-background": "#FFFFFF",
    "--feedback-icon-btn-size-desktop": "32px",
    "--citations-text-font-weight": "700",
    "--citations-desktop-button-font-size": "12px"
  }
}
```

---

## Implementation Status

This section documents which properties are fully implemented, partially implemented, or not yet implemented in the iOS framework.

### Legend

| Status | Description |
|--------|-------------|
| ✅ | Fully implemented - property is mapped and actively used in views |
| ⚠️ | Defined but unused - property is parsed but not rendered in any view |
| ❌ | Not supported - property exists in web JSON but is ignored by iOS |

### Metadata

| Property | Status | Notes |
|----------|--------|-------|
| `metadata.brandName` | ⚠️ | Parsed but not displayed in UI |
| `metadata.version` | ⚠️ | Parsed but not used |
| `metadata.language` | ⚠️ | Parsed but not used for localization |
| `metadata.namespace` | ⚠️ | Parsed but not used |

### Behavior

| Property | Status | Notes |
|----------|--------|-------|
| `behavior.multimodalCarousel.cardClickAction` | ⚠️ | Parsed but not implemented in carousel views |
| `behavior.input.enableVoiceInput` | ✅ | Controls mic button visibility |
| `behavior.input.disableMultiline` | ✅ | Controls input line limit |
| `behavior.input.showAiChatIcon` | ⚠️ | Parsed and mapped to component but not rendered |
| `behavior.chat.messageAlignment` | ✅ | Controls message horizontal alignment |
| `behavior.chat.messageWidth` | ✅ | Controls max message width |
| `behavior.privacyNotice.title` | ⚠️ | Parsed but no privacy dialog implemented |
| `behavior.privacyNotice.text` | ⚠️ | Parsed but no privacy dialog implemented |

### Disclaimer

| Property | Status | Notes |
|----------|--------|-------|
| `disclaimer.text` | ✅ | Rendered in ComposerDisclaimer |
| `disclaimer.links` | ✅ | Links are parsed and tappable |

### Text (Copy)

| Property | Status | Notes |
|----------|--------|-------|
| `text["welcome.heading"]` | ✅ | Used in ChatController for welcome message |
| `text["welcome.subheading"]` | ✅ | Used in ChatController for welcome message |
| `text["input.placeholder"]` | ✅ | Used in ComposerEditingView |
| `text["input.messageInput.aria"]` | ✅ | Used for accessibility |
| `text["input.send.aria"]` | ✅ | Used for accessibility |
| `text["input.aiChatIcon.tooltip"]` | ⚠️ | Parsed but AI icon not rendered |
| `text["input.mic.aria"]` | ✅ | Used for accessibility |
| `text["card.aria.select"]` | ✅ | Used in ChatMessageView |
| `text["carousel.prev.aria"]` | ✅ | Used in CarouselGroupView |
| `text["carousel.next.aria"]` | ✅ | Used in CarouselGroupView |
| `text["scroll.bottom.aria"]` | ⚠️ | Parsed but scroll button not implemented |
| `text["error.network"]` | ✅ | Used in ChatView |
| `text["loading.message"]` | ✅ | Used in ChatView placeholder |
| `text["feedback.dialog.title.positive"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.title.negative"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.question.positive"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.question.negative"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.notes"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.submit"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.cancel"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.dialog.notes.placeholder"]` | ✅ | Used in FeedbackOverlayView |
| `text["feedback.toast.success"]` | ⚠️ | Parsed but toast not implemented |
| `text["feedback.thumbsUp.aria"]` | ✅ | Used in SourcesListView |
| `text["feedback.thumbsDown.aria"]` | ✅ | Used in SourcesListView |

### Arrays

| Property | Status | Notes |
|----------|--------|-------|
| `arrays["welcome.examples"]` | ✅ | Used in ChatController |
| `arrays["feedback.positive.options"]` | ✅ | Used in FeedbackOverlayView |
| `arrays["feedback.negative.options"]` | ✅ | Used in FeedbackOverlayView |

### Assets

| Property | Status | Notes |
|----------|--------|-------|
| `assets.icons.company` | ⚠️ | Parsed but not rendered in any view |

### Theme Tokens - Typography

| CSS Variable | Status | Notes |
|--------------|--------|-------|
| `--font-family` | ✅ | Used in ChatView, ComposerEditingView |
| `--line-height-body` | ✅ | Used in ChatView for global line spacing |

### Theme Tokens - Colors

| CSS Variable | Status | Notes |
|--------------|--------|-------|
| `--color-primary` | ✅ | Used throughout UI |
| `--color-text` | ✅ | Used for text styling |
| `--main-container-background` | ✅ | Used in ChatView, ChatTopBar |
| `--main-container-bottom-background` | ✅ | Used in ChatComposer |
| `--message-blocker-background` | ✅ | Used in ChatView |
| `--message-user-background` | ✅ | Used in ChatMessageView |
| `--message-user-text` | ✅ | Used in ChatMessageView |
| `--message-concierge-background` | ✅ | Used in ChatMessageView, SourcesListView |
| `--message-concierge-text` | ✅ | Used in ChatMessageView |
| `--message-concierge-link-color` | ✅ | Used in SourceRowView |
| `--button-primary-background` | ✅ | Used in ConciergePressableButtonStyle |
| `--button-primary-text` | ✅ | Used in ConciergePressableButtonStyle |
| `--button-secondary-border` | ✅ | Used in ConciergePressableButtonStyle |
| `--button-secondary-text` | ✅ | Used in ConciergePressableButtonStyle |
| `--submit-button-fill-color` | ✅ | Used in ComposerSendButtonStyle |
| `--submit-button-fill-color-disabled` | ✅ | Used in ComposerSendButtonStyle |
| `--color-button-submit` | ✅ | Used in ComposerSendButtonStyle |
| `--button-disabled-background` | ✅ | Used in ConciergePressableButtonStyle |
| `--input-background` | ✅ | Used in ChatComposer (via components) |
| `--input-text-color` | ⚠️ | Mapped but text uses system colors |
| `--input-outline-color` | ⚠️ | Mapped but not rendered (only focus outline used) |
| `--input-focus-outline-color` | ✅ | Used in ChatComposer |
| `--citations-background-color` | ✅ | Used in MarkdownBlockView |
| `--citations-text-color` | ✅ | Used in MarkdownBlockView |
| `--feedback-icon-btn-background` | ✅ | Used in SourcesListView |
| `--disclaimer-color` | ⚠️ | Mapped but disclaimer uses primary.text |

### Theme Tokens - Layout

| CSS Variable | Status | Notes |
|--------------|--------|-------|
| `--input-height-mobile` | ✅ | Used in ChatComposer |
| `--input-border-radius-mobile` | ✅ | Used in ChatComposer |
| `--input-outline-width` | ⚠️ | Mapped but not rendered |
| `--input-focus-outline-width` | ✅ | Used in ChatComposer |
| `--input-font-size` | ✅ | Used in ComposerEditingView |
| `--input-button-height` | ✅ | Used in ComposerSendButtonStyle |
| `--input-button-width` | ✅ | Used in ComposerSendButtonStyle |
| `--input-button-border-radius` | ✅ | Used in ComposerSendButtonStyle |
| `--input-box-shadow` | ✅ | Used in ChatComposer |
| `--message-border-radius` | ✅ | Used in ChatMessageView, SourcesListView |
| `--message-padding` | ✅ | Used in ChatMessageView |
| `--message-max-width` | ✅ | Used in ChatMessageView |
| `--chat-interface-max-width` | ✅ | Used in ChatView |
| `--chat-history-padding` | ✅ | Used in ChatView |
| `--chat-history-padding-top-expanded` | ✅ | Used in MessageListView |
| `--chat-history-bottom-padding` | ✅ | Used in MessageListView |
| `--message-blocker-height` | ✅ | Used in MessageListView |
| `--border-radius-card` | ✅ | Used in ChatMessageView |
| `--multimodal-card-box-shadow` | ✅ | Used in ChatMessageView |
| `--button-height-s` | ✅ | Used in ButtonView |
| `--feedback-container-gap` | ✅ | Used in SourcesListView |
| `--feedback-icon-btn-size-desktop` | ✅ | Used in SourcesListView |
| `--citations-text-font-weight` | ✅ | Used in ChatMessageView |
| `--citations-desktop-button-font-size` | ✅ | Used in ChatMessageView |
| `--disclaimer-font-size` | ⚠️ | Mapped but not used in views |
| `--disclaimer-font-weight` | ⚠️ | Mapped but not used in views |
| `--welcome-input-order` | ⚠️ | Mapped but welcome layout not customizable |
| `--welcome-cards-order` | ⚠️ | Mapped but welcome layout not customizable |

### Unsupported CSS Variables

The following CSS variables appear in web theme configurations but are **not supported** on iOS:

| CSS Variable | Notes |
|--------------|-------|
| `--input-height` | Use `--input-height-mobile` instead |
| `--input-border-radius` | Use `--input-border-radius-mobile` instead |
| `--color-button-submit-hover` | Hover states not applicable on iOS |
| `--button-primary-hover` | Hover states not applicable on iOS |
| `--button-secondary-hover` | Hover states not applicable on iOS |
| `--color-button-secondary-hover-text` | Hover states not applicable on iOS |
| `--feedback-icon-btn-hover-background` | Hover states not applicable on iOS |
| `--message-alignment` | Use `behavior.chat.messageAlignment` instead |
| `--message-width` | Use `behavior.chat.messageWidth` instead |
