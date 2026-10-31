import Carbon

enum ShortcutKey: String, Codable, CaseIterable {
    case one = "1", two = "2", three = "3", four = "4"
    case q, w, e, r
    case a, s, d, f

    var label: String { "⌥\(rawValue.uppercased())" }
    var accessibilityLabel: String { "Option \(rawValue.uppercased())" }

    var keyCode: UInt32 {
        switch self {
        case .one: return UInt32(kVK_ANSI_1)
        case .two: return UInt32(kVK_ANSI_2)
        case .three: return UInt32(kVK_ANSI_3)
        case .four: return UInt32(kVK_ANSI_4)
        case .q: return UInt32(kVK_ANSI_Q)
        case .w: return UInt32(kVK_ANSI_W)
        case .e: return UInt32(kVK_ANSI_E)
        case .r: return UInt32(kVK_ANSI_R)
        case .a: return UInt32(kVK_ANSI_A)
        case .s: return UInt32(kVK_ANSI_S)
        case .d: return UInt32(kVK_ANSI_D)
        case .f: return UInt32(kVK_ANSI_F)
        }
    }

    var slotID: Int { Self.allCases.firstIndex(of: self)! }
    var eventID: UInt32 { UInt32(slotID + 1) }

    static func slotID(forEventID eventID: UInt32) -> Int? {
        guard (1...UInt32(allCases.count)).contains(eventID) else { return nil }
        return Int(eventID) - 1
    }

    static func defaultKey(for slotID: Int) -> ShortcutKey {
        let defaults = allCases
        return defaults.indices.contains(slotID) ? defaults[slotID] : .one
    }
}
