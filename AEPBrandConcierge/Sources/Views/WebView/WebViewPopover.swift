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
import WebKit

/// A full-screen popover presenting a web view with a close button and URL bar.
/// Slides up from the bottom and dismisses by sliding down.
struct WebViewPopover: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.openURL) private var openURL
    
    let url: URL
    let onDismiss: () -> Void
    
    @State private var currentURLString: String = ""
    @State private var isLoading: Bool = true
//    @State private var pageTitle: String = ""
    @State private var dragOffset: CGFloat = 0
    @State private var showCopiedFeedback: Bool = false
    
    private let dismissThreshold: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacer - tappable to dismiss, transparent to show app behind
            Color.clear
                .frame(height: 30)
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }
            
            // Main content with rounded corners
            VStack(spacing: 0) {
                // Drag indicator
                dragIndicator
                
                // Top bar with close button and URL
                topBar
                
                // WebView content
                ConciergeWebView(
                    url: url,
                    currentURLString: $currentURLString,
                    isLoading: $isLoading,
//                    pageTitle: $pageTitle,
                    onOpenDeepLink: { deepLinkURL in
                        openURL(deepLinkURL)
                    }
                )
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedCornerShape(radius: 16, corners: [.topLeft, .topRight]))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow dragging down
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .background(Color.clear)
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
        .onAppear {
            currentURLString = url.absoluteString
        }
    }
    
    private var dragIndicator: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(UIColor.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }
    
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Close button - uses primary color for visibility
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(theme.colors.primary.primary.color)
                        )
                }
                .accessibilityLabel("Close")
                
                // URL display
                urlBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Loading indicator
            if isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: theme.colors.primary.primary.color))
                    .frame(height: 2)
            } else {
                Divider()
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var urlBar: some View {
        Button(action: copyURLToClipboard) {
            HStack(spacing: 6) {
                // Lock icon for https
                if URL(string: currentURLString)?.scheme?.lowercased() == "https" {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                // Display full URL
                Text(currentURLString)
                    .font(.system(size: 13))
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 0)
                
                // Copy indicator or feedback
                if showCopiedFeedback {
                    Text("Copied!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.colors.primary.primary.color)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy URL")
        .accessibilityHint("Tap to copy the current URL to clipboard")
    }
    
    private func copyURLToClipboard() {
        UIPasteboard.general.string = currentURLString
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedFeedback = true
        }
        
        // Hide feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
}

/// UIViewRepresentable wrapper for WKWebView
struct ConciergeWebView: UIViewRepresentable {
    let url: URL
    @Binding var currentURLString: String
    @Binding var isLoading: Bool
//    @Binding var pageTitle: String
    var onOpenDeepLink: ((URL) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Set a non-transparent background to avoid black screen before content loads
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if the URL has changed from the original
        if webView.url != url && currentURLString == url.absoluteString {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ConciergeWebView
        
        init(_ parent: ConciergeWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            if let currentURL = webView.url?.absoluteString {
                parent.currentURLString = currentURL
            }
//            if let title = webView.title, !title.isEmpty {
//                parent.pageTitle = title
//            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // If it's a deep link, let the system handle it via the callback
            if ConciergeLinkHandler.isDeepLink(requestURL) {
                parent.onOpenDeepLink?(requestURL)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}

#Preview {
    WebViewPopover(
        url: URL(string: "https://www.adobe.com")!,
        onDismiss: {}
    )
    .conciergeTheme(ConciergeTheme())
}
