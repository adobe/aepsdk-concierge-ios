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

final class ConciergeXDMContextStoreTests: XCTestCase {

    private var store: ConciergeXDMContextStore!

    override func setUp() {
        super.setUp()
        store = ConciergeXDMContextStore(sessionIDProvider: { "session-1" })
    }

    private func assertEqual(_ lhs: [String: Any], _ rhs: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue((lhs as NSDictionary).isEqual(to: rhs), "\(lhs) is not equal to \(rhs)", file: file, line: line)
    }

    func test_emptyStore_snapshotIsEmpty() {
        assertEqual(store.snapshot(), [:])
    }

    func test_singleUpdate_isHeldVerbatim() throws {
        try store.update(["fan": ["seatSection": "112"]])
        assertEqual(store.snapshot(), ["fan": ["seatSection": "112"]])
    }

    func test_update_detachesMutableFoundationValuesFromCaller() throws {
        let nested = NSMutableDictionary(dictionary: ["tier": "gold"])
        let items = NSMutableArray(array: ["first"])
        try store.update(["loyalty": nested, "items": items])

        nested["tier"] = "platinum"
        items.add("second")

        assertEqual(store.snapshot(), ["loyalty": ["tier": "gold"], "items": ["first"]])
    }

    func test_snapshot_detachesMutableFoundationValuesFromStore() throws {
        try store.update(["loyalty": ["tier": "gold"]])
        var snapshot = store.snapshot()
        guard var loyalty = snapshot["loyalty"] as? [String: Any] else {
            XCTFail("Expected a nested dictionary in the snapshot")
            return
        }
        loyalty["tier"] = "platinum"
        snapshot["loyalty"] = loyalty

        assertEqual(store.snapshot(), ["loyalty": ["tier": "gold"]])
    }

    func test_snapshotForNewBackendSession_clearsContextOnlyAfterPriorSessionWasObserved() throws {
        try store.update(["loggedIn": true])
        assertEqual(store.snapshot(for: "session-1"), ["loggedIn": true])

        try store.update(["loyalty": ["tier": "gold"]])
        assertEqual(store.snapshot(for: "session-1"), ["loggedIn": true, "loyalty": ["tier": "gold"]])
        assertEqual(store.snapshot(for: "session-2"), [:])
    }

    func test_updateAfterSessionRollover_preservesOnlyNewFields() throws {
        var currentSessionID = "session-1"
        let store = ConciergeXDMContextStore(sessionIDProvider: { currentSessionID })
        try store.update(["old": true, "shared": "previous"])
        assertEqual(store.snapshot(for: currentSessionID), ["old": true, "shared": "previous"])

        currentSessionID = "session-2"
        try store.update(["new": true, "shared": "current"])

        assertEqual(store.snapshot(for: currentSessionID), ["new": true, "shared": "current"])
    }

    func test_snapshotAfterRolloverWithoutUpdate_dropsPreviousFields() throws {
        try store.update(["old": true])
        assertEqual(store.snapshot(for: "session-2"), [:])
    }

    func test_handoffMerge_keepsNestedNullsAsValuesAndPreservesSiblings() {
        let merged = ConciergeXDMContextStore.merging(
            ["commerce": ["order": ["purchaseID": NSNull()], "cart": NSNull()]],
            over: ["commerce": ["order": ["purchaseID": "old", "currency": "USD"], "cart": ["id": "123"]]]
        )
        assertEqual(merged, ["commerce": ["order": ["purchaseID": NSNull(), "currency": "USD"], "cart": NSNull()]])
    }

    func test_secondUpdate_addsNewTopLevelKey_withoutDisturbingTheFirst() throws {
        try store.update(["fan": ["seatSection": "112"]])
        try store.update(["loyalty": ["tier": "gold"]])

        assertEqual(store.snapshot(), ["fan": ["seatSection": "112"], "loyalty": ["tier": "gold"]])
    }

    func test_secondUpdate_replacesExistingTopLevelKey() throws {
        try store.update(["loyalty": ["tier": "gold"]])
        try store.update(["loyalty": ["tier": "platinum"]])

        assertEqual(store.snapshot(), ["loyalty": ["tier": "platinum"]])
    }

    func test_nestedPartialUpdate_mergesSiblingKeys_ratherThanReplacingTheWholeObject() throws {
        try store.update(["fan": ["seatSection": "112", "seatRow": "A"]])
        try store.update(["fan": ["seatRow": "B"]])

        assertEqual(store.snapshot(), ["fan": ["seatSection": "112", "seatRow": "B"]])
    }

    func test_nsNull_atTopLevel_removesTheKey() throws {
        try store.update(["fan": ["seatSection": "112"], "loyalty": ["tier": "gold"]])
        try store.update(["loyalty": NSNull()])

        assertEqual(store.snapshot(), ["fan": ["seatSection": "112"]])
    }

    func test_nsNull_nested_removesOnlyThatKey_leavingSiblingsIntact() throws {
        try store.update(["fan": ["seatSection": "112", "seatRow": "A"]])
        try store.update(["fan": ["seatSection": NSNull()]])

        assertEqual(store.snapshot(), ["fan": ["seatRow": "A"]])
    }

    func test_nsNull_nested_underMissingObject_doesNotPersistAsJsonNull() throws {
        try store.update(["fan": ["seatSection": NSNull()]])

        assertEqual(store.snapshot(), ["fan": [:]])
    }

    func test_nsNull_forAKeyThatIsNotPresent_isANoOp() throws {
        try store.update(["fan": ["seatSection": "112"]])
        try store.update(["loyalty": NSNull()])

        assertEqual(store.snapshot(), ["fan": ["seatSection": "112"]])
    }

    func test_nonJSONSerializableValue_throwsInvalidValue_andDoesNotMutateTheStore() {
        XCTAssertThrowsError(try store.update(["commerce": Date()])) { error in
            XCTAssertEqual(error as? ConciergeXDMContextError, .invalidValue)
        }
        assertEqual(store.snapshot(), [:])
    }

    func test_topLevelIdentityMapKey_throwsReservedKeyCollision_andDoesNotMutateTheStore() {
        XCTAssertThrowsError(try store.update(["identityMap": ["ECID": [["id": "abc"]]]])) { error in
            XCTAssertEqual(error as? ConciergeXDMContextError, .reservedKeyCollision)
        }
        assertEqual(store.snapshot(), [:])
    }

    func test_clear_emptiesTheStore() throws {
        try store.update(["fan": ["seatSection": "112"]])
        store.clear()

        assertEqual(store.snapshot(), [:])
    }
}
