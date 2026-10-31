import Carbon

private let quickLaunchSignature: OSType = 0x514C4348 // QLCH

private func quickLaunchEventHandler(
    _: EventHandlerCallRef?, event: EventRef?, context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let result = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
    )
    guard result == noErr, identifier.signature == quickLaunchSignature,
          let action = HotKeyAction.from(eventID: identifier.id) else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
    switch action {
    case .application(let slotID): manager.onPress?(slotID)
    case .toggleSettings: manager.onToggleSettings?()
    }
    return noErr
}

/// Owned for the app's lifetime. Carbon delivers application events on the main run loop.
final class HotKeyManager {
    struct RegistrationResult {
        var applicationErrors: [Int: OSStatus] = [:]
        var settingsError: OSStatus?
    }

    var onPress: ((Int) -> Void)?
    var onToggleSettings: (() -> Void)?
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []

    func register(slots: [SlotConfiguration]) -> RegistrationResult {
        unregisterKeys()
        let bindings = HotKeyBinding.plan(for: slots)
        var result = RegistrationResult()
        if handler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(
                GetApplicationEventTarget(), quickLaunchEventHandler, 1, &eventType,
                Unmanaged.passUnretained(self).toOpaque(), &handler
            )
            guard status == noErr else {
                for binding in bindings { recordError(status, for: binding.action, in: &result) }
                return result
            }
        }
        for binding in bindings {
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.keyCode, binding.modifiers,
                EventHotKeyID(signature: quickLaunchSignature, id: binding.eventID),
                GetApplicationEventTarget(), 0, &reference
            )
            if status == noErr, let reference {
                registrations.append(reference)
            } else {
                recordError(status, for: binding.action, in: &result)
            }
        }
        return result
    }

    private func recordError(_ status: OSStatus, for action: HotKeyAction, in result: inout RegistrationResult) {
        switch action {
        case .application(let slotID): result.applicationErrors[slotID] = status
        case .toggleSettings: result.settingsError = status
        }
    }

    private func unregisterKeys() {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
    }

    func stop() {
        unregisterKeys()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        onPress = nil
        onToggleSettings = nil
    }

    deinit { stop() }
}
