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
import AEPBrandConcierge

/// Collects timestamped lines from the auth token provider so they're observable in-app while
/// exercising the different `setAuthTokenProvider` scenarios below.
final class AuthTokenLog: ObservableObject, @unchecked Sendable {
    struct Line: Identifiable { let id = UUID(); let text: String }

    static let shared = AuthTokenLog()
    @Published private(set) var lines: [Line] = []

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Records a message. Safe to call from any thread (the provider runs on a background task).
    func record(_ message: String) {
        let text = "\(Self.formatter.string(from: Date()))  \(message)"
        let append = { [weak self] in
            guard let self = self else { return }
            self.lines.append(Line(text: text))
            if self.lines.count > 200 { self.lines.removeFirst(self.lines.count - 200) }
        }
        if Thread.isMainThread { append() } else { DispatchQueue.main.async(execute: append) }
    }

    func clear() { lines.removeAll() }
}

/// The auth token provider scenarios the demo can register, covering the happy paths plus the
/// edge cases (timeout, never-returns, nil/blank, and the clamped `.infinity` timeout).
enum AuthScenario: String, CaseIterable, Identifiable {
    case none
    case syncCached
    case asyncFast
    case asyncSlowRaisedTimeout
    case slowExceedsDefault
    case neverReturns
    case returnsNil
    case returnsBlank
    case infiniteTimeout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None (cleared)"
        case .syncCached: return "Sync cached token"
        case .asyncFast: return "Async refresh (300 ms)"
        case .asyncSlowRaisedTimeout: return "Async 5 s, timeout 8 s"
        case .slowExceedsDefault: return "Slow 5 s, default 3 s"
        case .neverReturns: return "Never returns"
        case .returnsNil: return "Returns nil"
        case .returnsBlank: return "Returns blank"
        case .infiniteTimeout: return "Timeout .infinity (edge)"
        }
    }

    /// The expected outcome, shown under the picker.
    var detail: String {
        switch self {
        case .none: return "No provider — every turn is sent without a token."
        case .syncCached: return "Returns a token synchronously — attached to every turn."
        case .asyncFast: return "Awaits ~300 ms then returns a token — attached (well within 3 s)."
        case .asyncSlowRaisedTimeout: return "Awaits 5 s with the timeout raised to 8 s — token still attaches."
        case .slowExceedsDefault: return "Awaits 5 s under the default 3 s timeout — SDK gives up; turn sent WITHOUT a token. Watch the log: the provider's late return arrives after the turn already went."
        case .neverReturns: return "Provider never returns — SDK gives up at 3 s and sends WITHOUT a token (the parked task is abandoned, not leaked forever)."
        case .returnsNil: return "Provider returns nil — turn sent without a token."
        case .returnsBlank: return "Provider returns whitespace — treated as no token."
        case .infiniteTimeout: return "timeout = .infinity — must NOT crash (clamped); token attaches."
        }
    }

    /// Registers the provider for this scenario, logging into `log`.
    func apply(log: AuthTokenLog) {
        switch self {
        case .none:
            Concierge.setAuthTokenProvider(nil)
            log.record("▶︎ Cleared provider — turns send without a token")

        case .syncCached:
            Concierge.setAuthTokenProvider {
                log.record("provider() → 'cached-token-abc123' (sync)")
                return "cached-token-abc123"
            }
            log.record("▶︎ Registered: sync cached token (default 3 s timeout)")

        case .asyncFast:
            Concierge.setAuthTokenProvider {
                log.record("provider() begin — awaiting 300 ms")
                try? await Task.sleep(nanoseconds: 300_000_000)
                log.record("provider() → 'refreshed-token-fast'")
                return "refreshed-token-fast"
            }
            log.record("▶︎ Registered: async 300 ms (default 3 s timeout)")

        case .asyncSlowRaisedTimeout:
            Concierge.setAuthTokenProvider(timeout: 8) {
                log.record("provider() begin — awaiting 5 s (timeout 8 s)")
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                log.record("provider() → 'slow-token-within-timeout'")
                return "slow-token-within-timeout"
            }
            log.record("▶︎ Registered: async 5 s with raised 8 s timeout")

        case .slowExceedsDefault:
            Concierge.setAuthTokenProvider {
                log.record("provider() begin — awaiting 5 s (default 3 s timeout)")
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                log.record("provider() → 'too-late' (SDK already sent the turn)")
                return "too-late"
            }
            log.record("▶︎ Registered: async 5 s under default 3 s — expect TIMEOUT")

        case .neverReturns:
            Concierge.setAuthTokenProvider {
                log.record("provider() begin — never returns")
                await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
                return nil
            }
            log.record("▶︎ Registered: never-returns — expect TIMEOUT at 3 s")

        case .returnsNil:
            Concierge.setAuthTokenProvider {
                log.record("provider() → nil")
                return nil
            }
            log.record("▶︎ Registered: returns nil — no token")

        case .returnsBlank:
            Concierge.setAuthTokenProvider {
                log.record("provider() → '   ' (blank)")
                return "   "
            }
            log.record("▶︎ Registered: returns blank — treated as no token")

        case .infiniteTimeout:
            Concierge.setAuthTokenProvider(timeout: .infinity) {
                log.record("provider() → 'inf-timeout-token'")
                return "inf-timeout-token"
            }
            log.record("▶︎ Registered: timeout .infinity (edge) — must not crash")
        }
    }
}

/// Demo screen that switches between auth token provider scenarios and shows a live provider log.
struct AuthTokenTestView: View {
    @StateObject private var log = AuthTokenLog.shared
    @State private var selected: AuthScenario = .none

    /// Switches to the chat tab and presents the Concierge chat so the tester can send a turn.
    let onOpenChat: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Auth Token Provider")
                .font(.headline)
                .padding(.top, 12)

            Picker("Scenario", selection: $selected) {
                ForEach(AuthScenario.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            Text(selected.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            Button(action: onOpenChat) {
                Text("Open chat & send a message")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            HStack {
                Text("Provider log").font(.subheadline.bold())
                Spacer()
                Button("Clear") { log.clear() }.font(.caption)
            }
            .padding(.horizontal)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(log.lines) { line in
                            Text(line.text)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: log.lines.count) { _ in
                    if let last = log.lines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .onAppear { selected.apply(log: log) }
        .onChange(of: selected) { newValue in newValue.apply(log: log) }
    }
}
