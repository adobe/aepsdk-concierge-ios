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
import XCTest
@testable import AEPBrandConcierge

final class NativeCardViewTests: NativeCardTestCase {
    @MainActor
    func testCardRowRendersItsCardFromTheChatStore() throws {
        NativeCardRegistry.register(type: "test.row") { _, _, _ in AnyView(Color.clear.frame(height: 80)) }
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(#"[{"type":"test.row"}]"#.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let template = try XCTUnwrap(controller.messages.first?.template)
        func height(store: NativeCardStore?) -> CGFloat {
            let view = ChatMessageView(template: template).environment(\.conciergeNativeCardStore, store)
            return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 320, height: 1000)).height
        }
        XCTAssertEqual(height(store: controller.nativeCards), 80, accuracy: 0.5)
        XCTAssertEqual(height(store: nil), 0, accuracy: 0.5, "A row without its chat's store renders nothing")
        controller.messages.removeAll()
        XCTAssertEqual(height(store: controller.nativeCards), 0, accuracy: 0.5, "A disposed card's row renders nothing")
    }
}
