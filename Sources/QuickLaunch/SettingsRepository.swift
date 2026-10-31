import Foundation

struct SlotConfiguration: Codable, Equatable, Identifiable {
    let id: Int
    var displayName: String
    var bundleIdentifier: String?
    var applicationPath: String?
    let shortcutKey: ShortcutKey

    var shortcut: String { shortcutKey.label }
    var isAssigned: Bool {
        [bundleIdentifier, applicationPath].contains {
            !($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static let defaults: [SlotConfiguration] = [
        .init(id: 0, displayName: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode"),
        .init(id: 1, displayName: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        .init(id: 2, displayName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
        .init(id: 3, displayName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
        .unassigned(for: .q), .unassigned(for: .w), .unassigned(for: .e), .unassigned(for: .r)
    ]

    static func unassigned(for key: ShortcutKey) -> SlotConfiguration {
        .init(id: key.slotID, displayName: "앱 미지정", shortcutKey: key)
    }

    init(id: Int, displayName: String, bundleIdentifier: String? = nil, applicationPath: String? = nil, shortcutKey: ShortcutKey? = nil) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
        self.shortcutKey = shortcutKey ?? .defaultKey(for: id)
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, bundleIdentifier, applicationPath, shortcutKey
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        displayName = try values.decode(String.self, forKey: .displayName)
        bundleIdentifier = try values.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        applicationPath = try values.decodeIfPresent(String.self, forKey: .applicationPath)
        // v1.0 saves have no key; unsupported values keep their original numbered slot.
        shortcutKey = (try? values.decode(ShortcutKey.self, forKey: .shortcutKey)) ?? .defaultKey(for: id)
    }
}

/// Migrates old four-slot assignments by their selected key, then fixes all eight IDs.
struct SettingsRepository {
    static let key = "applicationSlots.v1"
    let defaults: UserDefaults

    var hasSavedSettings: Bool { defaults.object(forKey: Self.key) != nil }

    func load() -> [SlotConfiguration] {
        guard let data = defaults.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode([SlotConfiguration].self, from: data) else {
            return SlotConfiguration.defaults
        }
        // A saved configuration defines its own assignments. Newly added or vacated
        // keys stay unassigned instead of unexpectedly launching a default app.
        var slots = ShortcutKey.allCases.map { SlotConfiguration.unassigned(for: $0) }
        var used: Set<ShortcutKey> = []
        for slot in saved where (0..<ShortcutKey.allCases.count).contains(slot.id) {
            guard !slot.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  used.insert(slot.shortcutKey).inserted else { continue }
            let key = slot.shortcutKey
            slots[key.slotID] = SlotConfiguration(
                id: key.slotID, displayName: slot.isAssigned ? slot.displayName : "앱 미지정",
                bundleIdentifier: slot.bundleIdentifier, applicationPath: slot.applicationPath,
                shortcutKey: key
            )
        }
        return slots
    }

    func save(_ slots: [SlotConfiguration]) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
