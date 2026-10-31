import Carbon
import XCTest
@testable import QuickLaunch

final class HotKeyBindingTests: XCTestCase {
    func testSettingsKeyRemainsRegisteredWithNoAssignedApplications() {
        let emptySlots = ShortcutKey.allCases.map { SlotConfiguration.unassigned(for: $0) }
        let bindings = HotKeyBinding.plan(for: emptySlots)
        XCTAssertEqual(bindings.count, 1)
        XCTAssertEqual(bindings[0].action, .toggleSettings)
        XCTAssertEqual(bindings[0].eventID, 100)
        XCTAssertEqual(bindings[0].keyCode, 50)
        XCTAssertEqual(bindings[0].modifiers, UInt32(optionKey))
        XCTAssertEqual(bindings[0].modifiers & UInt32(shiftKey), 0)
    }

    func testSettingsEventDoesNotOverlapEightApplicationEvents() {
        let slots = ShortcutKey.allCases.map {
            SlotConfiguration(id: $0.slotID, displayName: "App \($0.rawValue)", bundleIdentifier: "example.\($0.rawValue)")
        }
        let bindings = HotKeyBinding.plan(for: slots)
        XCTAssertEqual(bindings.count, 9)
        XCTAssertEqual(Set(bindings.map(\.eventID)).count, 9)
        for key in ShortcutKey.allCases {
            XCTAssertEqual(HotKeyAction.from(eventID: key.eventID), .application(slotID: key.slotID))
        }
        XCTAssertEqual(HotKeyAction.from(eventID: 100), .toggleSettings)
        for invalidID: UInt32 in [0, 9, 99, UInt32.max] {
            XCTAssertNil(HotKeyAction.from(eventID: invalidID))
        }
    }

    func testUnassignedAppKeysStayExcludedWhileSettingsIsIncluded() {
        XCTAssertEqual(HotKeyBinding.plan(for: SlotConfiguration.defaults).map(\.eventID), [1, 2, 3, 4, 100])
    }

    func testToggleHidesOnlyAnActiveFrontWindowWithoutSheet() {
        XCTAssertEqual(SettingsToggleAction.decide(isVisible: true, isMiniaturized: false,
            isKeyWindow: true, isApplicationActive: true, hasAttachedSheet: false), .hide)
        let showStates: [(visible: Bool, minimized: Bool, key: Bool, active: Bool, sheet: Bool)] = [
            (false, false, false, false, false),
            (true, false, false, false, false),
            (true, true, false, true, false),
            (true, false, true, false, false),
            (true, false, false, true, true),
            (true, false, true, true, true)
        ]
        for state in showStates {
            XCTAssertEqual(SettingsToggleAction.decide(isVisible: state.visible, isMiniaturized: state.minimized,
                isKeyWindow: state.key, isApplicationActive: state.active, hasAttachedSheet: state.sheet), .show,
                "Unexpected action for \(state)")
        }
    }
}
