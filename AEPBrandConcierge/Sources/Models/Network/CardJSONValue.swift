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

import Foundation

/// Bounded JSON tree with exact Foundation-representable numbers.
enum CardJSONValue: Codable {
    case object([String: CardJSONValue])
    case array([CardJSONValue])
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case number(Decimal)
    case boolean(Bool)
    case null

    private struct JSONKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    /// The structural budget for native card JSON, shared by raw elements and saved state. The root is
    /// at depth zero, and every value and container counts as one node.
    static let maximumDepth = 64
    static let maximumNodes = 100_000

    private static let sourceNumbersKey = CodingUserInfoKey(rawValue: "concierge.cardJSON.sourceNumbers")!
    private static let nativeCardTypesKey = CodingUserInfoKey(rawValue: "concierge.cardJSON.nativeCardTypes")!

    /// Decodes with exact source numbers, capturing raw JSON only for elements of `nativeCardTypes`.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data,
                                     nativeCardTypes: Set<String> = NativeCardRegistry.registeredTypes) throws -> T {
        let decoder = JSONDecoder()
        decoder.userInfo[sourceNumbersKey] = SourceNumbers(data: data)
        decoder.userInfo[nativeCardTypesKey] = nativeCardTypes
        return try decoder.decode(type, from: data)
    }

    /// Whether `decoder` captures elements of `elementType` as native card JSON. Decoders not created
    /// by `decode(_:from:nativeCardTypes:)` never do.
    static func capturesNativeCard(ofType elementType: String?, in decoder: Decoder) -> Bool {
        guard let elementType, let nativeCardTypes = decoder.userInfo[nativeCardTypesKey] as? Set<String> else {
            return false
        }
        return nativeCardTypes.contains(elementType)
    }

    static func decodeObject(from decoder: Decoder) throws -> [String: CardJSONValue] {
        var nodeCount = 0
        guard case .object(let object) = try decode(from: decoder, depth: 0, nodeCount: &nodeCount) else {
            throw DecodingError.typeMismatch(
                [String: CardJSONValue].self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a JSON object")
            )
        }
        return object
    }

    init(from decoder: Decoder) throws {
        var nodeCount = 0
        self = try Self.decode(from: decoder, depth: 0, nodeCount: &nodeCount)
    }

    private static func decode(from decoder: Decoder, depth: Int, nodeCount: inout Int) throws -> CardJSONValue {
        nodeCount += 1
        guard depth <= maximumDepth, nodeCount <= maximumNodes else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "JSON value exceeds the card safety budget")
            )
        }

        let scalar = try decoder.singleValueContainer()
        if scalar.decodeNil() { return .null }
        if let value = try? scalar.decode(Bool.self) { return .boolean(value) }
        if let value = try? scalar.decode(String.self) { return .string(value) }
        if let source = decoder.userInfo[sourceNumbersKey] as? SourceNumbers,
           let token = try source.token(at: decoder.codingPath) {
            if let value = Int64(token) { return .integer(value) }
            if let value = UInt64(token) { return .unsignedInteger(value) }
            let value = NSDecimalNumber(string: token, locale: Locale(identifier: "en_US_POSIX"))
            guard value != .notANumber,
                  let original = normalizedNumber(token),
                  original == normalizedNumber(value.stringValue) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath,
                                          debugDescription: "JSON number cannot be preserved exactly")
                )
            }
            return .number(value.decimalValue)
        }
        // A Decoder alone cannot expose the original numeric token, so it cannot prove fidelity.
        if (try? scalar.decode(Decimal.self)) != nil || (try? scalar.decode(Double.self)) != nil {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Native JSON numbers require source-aware decoding")
            )
        }

        if let keyed = try? decoder.container(keyedBy: JSONKey.self) {
            var object: [String: CardJSONValue] = [:]
            for key in keyed.allKeys {
                object[key.stringValue] = try decode(from: keyed.superDecoder(forKey: key),
                                                     depth: depth + 1, nodeCount: &nodeCount)
            }
            return .object(object)
        }

        var unkeyed = try decoder.unkeyedContainer()
        var array: [CardJSONValue] = []
        while !unkeyed.isAtEnd {
            array.append(try decode(from: unkeyed.superDecoder(), depth: depth + 1,
                                    nodeCount: &nodeCount))
        }
        return .array(array)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .unsignedInteger(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var foundationValue: Any {
        switch self {
        case .object(let value): return value.mapValues(\.foundationValue)
        case .array(let value): return value.map(\.foundationValue)
        case .string(let value): return value
        case .integer(let value): return NSNumber(value: value)
        case .unsignedInteger(let value): return NSNumber(value: value)
        case .number(let value): return NSDecimalNumber(decimal: value)
        case .boolean(let value): return NSNumber(value: value)
        case .null: return NSNull()
        }
    }

    /// Compares numeric values without floating-point conversion, including exponent notation.
    private static func normalizedNumber(_ token: String) -> String? {
        let parts = token.lowercased().split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count <= 2, let mantissa = parts.first else { return nil }
        let exponent: Int
        if parts.count == 2 {
            guard let parsed = Int(parts[1]) else { return nil }
            exponent = parsed
        } else {
            exponent = 0
        }
        let bytes = Array(mantissa.utf8)
        let negative = bytes.first == 45
        let point = bytes.firstIndex(of: 46)
        let fractionCount = point.map { bytes.count - $0 - 1 } ?? 0
        let digits = bytes.filter { (48...57).contains($0) }
        guard let first = digits.firstIndex(where: { $0 != 48 }) else { return "0" }
        guard let last = digits.lastIndex(where: { $0 != 48 }) else { return "0" }
        let (scale, scaleOverflow) = exponent.subtractingReportingOverflow(fractionCount)
        let (power, powerOverflow) = scale.addingReportingOverflow(digits.count - last - 1)
        guard !scaleOverflow, !powerOverflow else { return nil }
        return (negative ? "-" : "") + String(decoding: digits[first...last], as: UTF8.self) + "e\(power)"
    }

    /// Lazily indexes number tokens by coding path; Foundation remains the JSON syntax validator.
    private final class SourceNumbers {
        private let data: Data
        private var indexedTokens: Result<[[String]: String], Error>?

        init(data: Data) {
            self.data = data
        }

        func token(at path: [CodingKey]) throws -> String? {
            if indexedTokens == nil {
                indexedTokens = Result {
                    var scanner = NumberScanner(bytes: Array(data))
                    try scanner.scanValue(path: [])
                    return scanner.tokens
                }
            }
            let key = path.map { $0.intValue.map { "i:\($0)" } ?? "k:\($0.stringValue)" }
            let tokens = try indexedTokens?.get()
            return tokens?[key]
        }
    }

    private struct NumberScanner {
        let bytes: [UInt8]
        var index = 0
        var tokens: [[String]: String] = [:]

        mutating func scanValue(path: [String]) throws {
            skipWhitespace()
            guard index < bytes.count, path.count <= 512 else { throw invalidSource() }
            switch bytes[index] {
            case 123:
                index += 1
                skipWhitespace()
                if consume(125) { return }
                var keys = Set<String>()
                repeat {
                    skipWhitespace()
                    let range = try scanString()
                    let key = try JSONDecoder().decode(String.self, from: Data(bytes[range]))
                    guard keys.insert(key).inserted else { throw invalidSource() }
                    skipWhitespace()
                    guard consume(58) else { throw invalidSource() }
                    try scanValue(path: path + ["k:\(key)"])
                    skipWhitespace()
                } while consume(44)
                guard consume(125) else { throw invalidSource() }
            case 91:
                index += 1
                skipWhitespace()
                if consume(93) { return }
                var position = 0
                repeat {
                    try scanValue(path: path + ["i:\(position)"])
                    position += 1
                    skipWhitespace()
                } while consume(44)
                guard consume(93) else { throw invalidSource() }
            case 34:
                _ = try scanString()
            default:
                let start = index
                while index < bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) {
                    index += 1
                }
                guard index > start else { throw invalidSource() }
                if bytes[start] == 45 || (48...57).contains(bytes[start]) {
                    tokens[path] = String(decoding: bytes[start..<index], as: UTF8.self)
                }
            }
        }

        private mutating func scanString() throws -> Range<Int> {
            let start = index
            guard consume(34) else { throw invalidSource() }
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == 34 { return start..<index }
                if byte == 92 { index += 1 }
            }
            throw invalidSource()
        }

        private mutating func skipWhitespace() {
            while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) {
                index += 1
            }
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        private func invalidSource() -> DecodingError {
            .dataCorrupted(.init(codingPath: [], debugDescription: "Cannot locate native JSON number source"))
        }
    }
}
