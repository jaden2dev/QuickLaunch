import Foundation
import XCTest
@testable import QuickLaunch

final class SettingsRepositoryTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var repository: SettingsRepository!

    override func setUp() {
        suite = "QuickLaunch.Tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        repository = SettingsRepository(defaults: defaults)
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testFreshInstallHasTwelveFixedKeysAndFourAssignedDefaults() {
        XCTAssertFalse(repository.hasSavedSettings)
        XCTAssertEqual(repository.load(), SlotConfiguration.defaults)
        XCTAssertEqual(repository.load().map(\.shortcut), ["⌥1", "⌥2", "⌥3", "⌥4", "⌥Q", "⌥W", "⌥E", "⌥R", "⌥A", "⌥S", "⌥D", "⌥F"])
        XCTAssertEqual(repository.load().prefix(4).filter(\.isAssigned).count, 4)
        XCTAssertTrue(repository.load().suffix(8).allSatisfy { !$0.isAssigned })
    }

    func testCustomLetterApplicationAndUnassignedSlotsSurviveReload() {
        var slots = SlotConfiguration.defaults
        slots[11] = .init(id: 11, displayName: "Custom App", bundleIdentifier: "example.custom", applicationPath: "/Volumes/External Apps/Custom App.app")
        repository.save(slots)
        XCTAssertTrue(repository.hasSavedSettings)
        XCTAssertEqual(SettingsRepository(defaults: defaults).load(), slots)
    }

    func testV13EightSlotSaveKeepsEachAppAndAddsFourUnassignedSlots() {
        let oldSlots = ShortcutKey.allCases.prefix(8).map { key in
            SlotConfiguration(id: key.slotID, displayName: "Saved app \(key.rawValue)",
                bundleIdentifier: "custom.\(key.rawValue)", applicationPath: "/External Apps/App \(key.rawValue).app")
        }
        repository.save(oldSlots)
        let loaded = repository.load()
        XCTAssertEqual(Array(loaded.prefix(8)), oldSlots)
        XCTAssertEqual(loaded.suffix(4).map(\.shortcutKey), [.a, .s, .d, .f])
        XCTAssertTrue(loaded.suffix(4).allSatisfy { !$0.isAssigned })
        repository.save(loaded)
        XCTAssertEqual(repository.load(), loaded)
    }

    func testCorruptDataFallsBackWithoutCrashing() {
        defaults.set(Data("broken JSON".utf8), forKey: SettingsRepository.key)
        XCTAssertEqual(repository.load(), SlotConfiguration.defaults)
    }

    func testOriginalFourSlotSaveMigratesWithoutChangingApplications() {
        let legacy = """
        [{"id":0,"displayName":"My Editor","bundleIdentifier":"custom.editor","applicationPath":"/Volumes/Apps/My Editor.app"},
         {"id":1,"displayName":"My Browser","bundleIdentifier":"custom.browser"},
         {"id":2,"displayName":"My Shell","bundleIdentifier":"custom.shell"},
         {"id":3,"displayName":"My Chat","bundleIdentifier":"custom.chat"}]
        """
        defaults.set(Data(legacy.utf8), forKey: SettingsRepository.key)
        let loaded = repository.load()
        XCTAssertEqual(loaded.prefix(4).map(\.displayName), ["My Editor", "My Browser", "My Shell", "My Chat"])
        XCTAssertEqual(loaded[0].applicationPath, "/Volumes/Apps/My Editor.app")
        XCTAssertTrue(loaded.suffix(8).allSatisfy { !$0.isAssigned })
    }

    func testSelectableFourSlotSaveMigratesByShortcutInsteadOfOldID() {
        let saved: [SlotConfiguration] = [
            .init(id: 0, displayName: "Editor", bundleIdentifier: "custom.editor", shortcutKey: .r),
            .init(id: 1, displayName: "Browser", applicationPath: "/Apps/Browser.app", shortcutKey: .q),
            .init(id: 2, displayName: "Shell", bundleIdentifier: "custom.shell", shortcutKey: .one),
            .init(id: 3, displayName: "Chat", bundleIdentifier: "custom.chat", shortcutKey: .e)
        ]
        repository.save(saved)
        let loaded = repository.load()
        XCTAssertEqual(loaded.count, 12)
        XCTAssertEqual(loaded.map(\.id), Array(0..<12))
        XCTAssertEqual(loaded.map(\.shortcutKey), ShortcutKey.allCases)
        XCTAssertEqual(loaded[7].displayName, "Editor")
        XCTAssertEqual(loaded[4].applicationPath, "/Apps/Browser.app")
        XCTAssertEqual(loaded[0].bundleIdentifier, "custom.shell")
        XCTAssertEqual(loaded[6].bundleIdentifier, "custom.chat")
        XCTAssertTrue([1, 2, 3, 5].allSatisfy { !loaded[$0].isAssigned })
        repository.save(loaded)
        XCTAssertEqual(repository.load(), loaded)
    }

    func testUnsupportedShortcutKeepsOriginalNumberedApplication() {
        let invalid = """
        [{"id":0,"displayName":"Saved Editor","bundleIdentifier":"custom.editor","shortcutKey":"x"}]
        """
        defaults.set(Data(invalid.utf8), forKey: SettingsRepository.key)
        XCTAssertEqual(repository.load()[0].bundleIdentifier, "custom.editor")
        XCTAssertEqual(repository.load()[0].shortcutKey, .one)
    }

    func testDuplicateAndInvalidSavedEntriesNormalizeWithoutDuplicateKeys() {
        let saved: [SlotConfiguration] = [
            .init(id: 0, displayName: "First", bundleIdentifier: "first.app", shortcutKey: .q),
            .init(id: 1, displayName: "Duplicate", bundleIdentifier: "second.app", shortcutKey: .q),
            .init(id: 99, displayName: "Out of bounds", bundleIdentifier: "invalid.app", shortcutKey: .r),
            .init(id: 2, displayName: "  ", bundleIdentifier: "blank.app")
        ]
        repository.save(saved)
        let loaded = repository.load()
        XCTAssertEqual(loaded.count, 12)
        XCTAssertEqual(Set(loaded.map(\.shortcutKey)).count, 12)
        XCTAssertEqual(loaded[4].bundleIdentifier, "first.app")
        XCTAssertEqual(loaded.filter(\.isAssigned).count, 1)
    }

    func testTwelveCarbonEventsRouteToCorrectFixedSlot() {
        XCTAssertEqual(ShortcutKey.allCases.map(\.keyCode), [18, 19, 20, 21, 12, 13, 14, 15, 0, 1, 2, 3])
        XCTAssertEqual(ShortcutKey.allCases.map(\.eventID), Array(1...12).map(UInt32.init))
        for key in ShortcutKey.allCases {
            XCTAssertEqual(ShortcutKey.slotID(forEventID: key.eventID), key.slotID)
            XCTAssertEqual(SlotConfiguration.defaults[key.slotID].shortcutKey, key)
        }
        XCTAssertNil(ShortcutKey.slotID(forEventID: 0))
        XCTAssertNil(ShortcutKey.slotID(forEventID: 13))
        XCTAssertNil(ShortcutKey.slotID(forEventID: UInt32.max))
    }

    func testBlankAssignmentsAreNotRegisteredCandidates() {
        let slot = SlotConfiguration(id: 4, displayName: "Unset", bundleIdentifier: "  ", applicationPath: "\n")
        XCTAssertFalse(slot.isAssigned)
        XCTAssertEqual(SlotConfiguration.defaults.filter(\.isAssigned).map(\.shortcutKey), [.one, .two, .three, .four])
    }
}
