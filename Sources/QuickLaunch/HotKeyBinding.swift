import Carbon

/// Event IDs are independent of key codes; ID 100 never overlaps app slots 1…12.
enum HotKeyAction: Equatable {
    case application(slotID: Int)
    case toggleSettings

    static let settingsEventID: UInt32 = 100

    static func from(eventID: UInt32) -> HotKeyAction? {
        if eventID == settingsEventID { return .toggleSettings }
        return ShortcutKey.slotID(forEventID: eventID).map { .application(slotID: $0) }
    }
}

struct HotKeyBinding: Equatable {
    let action: HotKeyAction
    let eventID: UInt32
    let keyCode: UInt32
    // The physical grave/tilde key uses Option only, never Shift.
    let modifiers: UInt32 = UInt32(optionKey)

    static func plan(for slots: [SlotConfiguration]) -> [HotKeyBinding] {
        let applications = slots.filter(\.isAssigned).map { slot in
            HotKeyBinding(action: .application(slotID: slot.id), eventID: slot.shortcutKey.eventID, keyCode: slot.shortcutKey.keyCode)
        }
        return applications + [HotKeyBinding(action: .toggleSettings, eventID: HotKeyAction.settingsEventID, keyCode: UInt32(kVK_ANSI_Grave))]
    }
}

enum SettingsToggleAction: Equatable {
    case show, hide

    static func decide(isVisible: Bool, isMiniaturized: Bool, isKeyWindow: Bool,
                       isApplicationActive: Bool, hasAttachedSheet: Bool) -> SettingsToggleAction {
        // An open picker stays attached and visible; never strand a modal sheet.
        isVisible && !isMiniaturized && isKeyWindow && isApplicationActive && !hasAttachedSheet ? .hide : .show
    }
}
