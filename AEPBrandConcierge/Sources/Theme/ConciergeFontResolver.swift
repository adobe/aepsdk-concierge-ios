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

import UIKit
import CoreText
import AEPServices

/// Resolves custom fonts from a `ConciergeFontFamilySpec` with hybrid lookup:
/// first tries fonts already registered with the system (e.g. via Info.plist),
/// then falls back to discovering and registering font files from the app bundle at runtime.
final class ConciergeFontResolver {
    static let shared = ConciergeFontResolver()

    private let supportedExtensions = ["ttf", "otf"]

    /// Maps a spec slot basename to its resolved PostScript font name.
    private var resolvedNames: [String: String] = [:]
    /// Basenames that we already tried and failed to resolve.
    private var failedBasenames: Set<String> = []

    private let lock = NSLock()

    private init() {}

    /// Resolves a UIFont for the given spec, size, and weight.
    /// Returns nil if the spec is nil/empty or no matching font can be found,
    /// signaling the caller to fall back to system font.
    func resolve(spec: ConciergeFontFamilySpec?, size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        guard let spec = spec, !spec.isEmpty else { return nil }

        guard let basename = basename(for: weight, in: spec) else { return nil }

        if let fontName = cachedName(for: basename) {
            return UIFont(name: fontName, size: size)
        }

        if isFailed(basename) { return nil }

        // Approach C — hybrid: try registered first, then bundle discovery
        if let font = tryRegistered(basename: basename, size: size) {
            cache(fontName: font.fontName, for: basename)
            return font
        }

        if let font = tryBundleRegistration(basename: basename, size: size) {
            cache(fontName: font.fontName, for: basename)
            return font
        }

        markFailed(basename)
        Log.warning(label: ConciergeConstants.LOG_TAG,
                    "Font '\(basename)' not found. Ensure the font file is included in the app bundle " +
                    "and listed in Info.plist, or placed as a .ttf/.otf in the bundle.")
        return nil
    }

    // MARK: - Slot-to-basename mapping

    private func basename(for weight: UIFont.Weight, in spec: ConciergeFontFamilySpec) -> String? {
        let direct: String? = {
            switch weight {
            case .ultraLight, .thin: return spec.thin
            case .light:             return spec.light
            case .regular:           return spec.regular
            case .medium, .semibold: return spec.regular
            case .bold, .heavy:      return spec.bold
            case .black:             return spec.black
            default:                 return spec.regular
            }
        }()

        if let name = direct, !name.isEmpty { return name }

        // Fall back to regular if the exact slot is empty
        if let regular = spec.regular, !regular.isEmpty { return regular }

        // Last resort: return any non-nil slot
        return [spec.thin, spec.light, spec.regular, spec.italic, spec.bold, spec.black]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }

    // MARK: - Hybrid resolution

    /// Try loading the font by name — works when the font is already registered via Info.plist.
    private func tryRegistered(basename: String, size: CGFloat) -> UIFont? {
        UIFont(name: basename, size: size)
    }

    /// Search the main bundle for a matching .ttf/.otf file and register it at runtime.
    private func tryBundleRegistration(basename: String, size: CGFloat) -> UIFont? {
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: basename, withExtension: ext) {
                if registerFont(at: url) {
                    return UIFont(name: basename, size: size)
                        ?? fontFromFile(at: url, size: size)
                }
            }
        }
        return nil
    }

    private func registerFont(at url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            if let cfError = error?.takeRetainedValue() {
                let nsError = cfError as Error as NSError
                // Code 105 = already registered, which is fine
                if nsError.code == 105 { return true }
                Log.debug(label: ConciergeConstants.LOG_TAG,
                          "Font registration failed for \(url.lastPathComponent): \(nsError.localizedDescription)")
            }
            return false
        }
        return true
    }

    /// When the PostScript name doesn't match the filename, extract it from the font file directly.
    private func fontFromFile(at url: URL, size: CGFloat) -> UIFont? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else { return nil }
        let ctFont = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        if let postScriptName = CTFontCopyPostScriptName(ctFont) as String? {
            return UIFont(name: postScriptName, size: size)
        }
        return nil
    }

    // MARK: - Cache

    private func cachedName(for basename: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return resolvedNames[basename]
    }

    private func cache(fontName: String, for basename: String) {
        lock.lock()
        defer { lock.unlock() }
        resolvedNames[basename] = fontName
    }

    private func isFailed(_ basename: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return failedBasenames.contains(basename)
    }

    private func markFailed(_ basename: String) {
        lock.lock()
        defer { lock.unlock() }
        failedBasenames.insert(basename)
    }
}
