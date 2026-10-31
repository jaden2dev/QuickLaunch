import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

final class LauncherStore: ObservableObject {
    @Published private(set) var slots: [SlotConfiguration]
    @Published private(set) var registrationErrors: [Int: OSStatus] = [:]
    @Published private(set) var settingsShortcutError: OSStatus?
    var onToggleSettings: (() -> Void)?
    @Published private(set) var launching: Set<Int> = []
    @Published var notice: String?

    private let repository = SettingsRepository(defaults: .standard)
    private let hotKeys = HotKeyManager()
    private var appPicker: NSOpenPanel?
    init() { slots = repository.load() }

    func start() {
        repository.save(slots)
        hotKeys.onToggleSettings = { [weak self] in self?.onToggleSettings?() }
        hotKeys.onPress = { [weak self] index in self?.launch(index) }
        retryShortcuts()
    }

    func stop() { hotKeys.stop() }

    func retryShortcuts() {
        let result = hotKeys.register(slots: slots)
        registrationErrors = result.applicationErrors
        settingsShortcutError = result.settingsError
    }

    var settingsShortcutErrorMessage: String? {
        guard let status = settingsShortcutError else { return nil }
        return "설정 단축키 ⌥ + ₩ / ` · " + errorMessage(for: status)
    }

    func registrationErrorMessage(for index: Int) -> String? {
        guard let status = registrationErrors[index] else { return nil }
        return errorMessage(for: status)
    }

    private func errorMessage(for status: OSStatus) -> String {
        if status == eventHotKeyExistsErr { return "다른 앱이 이 단축키를 사용 중입니다." }
        return "단축키 등록 실패 (오류 \(status))"
    }

    func applicationURL(for slot: SlotConfiguration) -> URL? {
        if let path = slot.applicationPath {
            let url = URL(fileURLWithPath: path)
            if isApplication(url) { return url }
        }
        if let identifier = slot.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
           isApplication(url) { return url }
        return nil
    }

    private func isApplication(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "app" &&
        Bundle(url: url)?.bundleURL != nil &&
        (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true
    }

    func chooseApplication(for index: Int, window: NSWindow?) {
        guard slots.indices.contains(index), appPicker == nil else { return }
        let picker = NSOpenPanel()
        picker.title = "\(slots[index].shortcut)에 연결할 앱 선택"
        picker.prompt = "이 앱 사용"
        picker.allowedContentTypes = [.application]
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.canChooseFiles = true
        picker.treatsFilePackagesAsDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        appPicker = picker
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            defer { self.appPicker = nil }
            guard response == .OK, let url = picker.url else { return }
            guard self.isApplication(url), let bundle = Bundle(url: url) else {
                self.notice = "실행할 수 있는 .app 응용 프로그램을 선택해 주세요."
                return
            }
            self.slots[index] = SlotConfiguration(
                id: index,
                displayName: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                bundleIdentifier: bundle.bundleIdentifier,
                applicationPath: url.path,
                shortcutKey: self.slots[index].shortcutKey
            )
            self.repository.save(self.slots)
            self.retryShortcuts()
            self.notice = nil
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window { picker.beginSheetModal(for: window, completionHandler: completion) }
        else { picker.begin(completionHandler: completion) }
    }

    func launch(_ index: Int) {
        guard slots.indices.contains(index), !launching.contains(index) else { return }
        let slot = slots[index]
        guard slot.isAssigned else { return }
        guard let url = applicationURL(for: slot) else {
            showLaunchError("\(slot.displayName)을(를) 찾을 수 없습니다. 메뉴 막대의 QuickLaunch → 설정에서 앱을 다시 선택해 주세요.")
            return
        }
        launching.insert(index)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.launching.remove(index)
                if let error {
                    self?.showLaunchError("\(slot.displayName)을(를) 열지 못했습니다.\n\(error.localizedDescription)")
                }
            }
        }
    }

    private func showLaunchError(_ message: String) {
        notice = message
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "앱을 열 수 없습니다"
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    func restoreDefaults() {
        slots = SlotConfiguration.defaults
        repository.save(slots)
        retryShortcuts()
        notice = "기본 앱 연결과 단축키를 복원했습니다."
    }
}
