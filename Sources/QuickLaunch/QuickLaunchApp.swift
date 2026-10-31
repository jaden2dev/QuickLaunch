import AppKit
import SwiftUI

@main
struct QuickLaunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("QuickLaunch", systemImage: "bolt.circle") {
            LauncherMenu(store: delegate.store, showSettings: { delegate.showSettings() })
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = LauncherStore()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        store.onToggleSettings = { [weak self] in self?.toggleSettings() }
        store.start()
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) { store.stop() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
            )
            window.title = "QuickLaunch 설정"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store, chooseApp: { [weak self] index in
                self?.store.chooseApplication(for: index, window: self?.settingsWindow)
            }))
            window.center()
            settingsWindow = window
        }
        store.objectWillChange.send()
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.attachedSheet?.makeKeyAndOrderFront(nil)
    }

    private func toggleSettings() {
        guard let window = settingsWindow else { showSettings(); return }
        let action = SettingsToggleAction.decide(
            isVisible: window.isVisible, isMiniaturized: window.isMiniaturized,
            isKeyWindow: window.isKeyWindow, isApplicationActive: NSApplication.shared.isActive,
            hasAttachedSheet: window.attachedSheet != nil
        )
        switch action {
        case .show: showSettings()
        case .hide: window.orderOut(nil)
        }
    }
}

private struct LauncherMenu: View {
    @ObservedObject var store: LauncherStore
    let showSettings: () -> Void

    var body: some View {
        ForEach(store.slots) { slot in
            Button { store.launch(slot.id) } label: {
                Text(slot.isAssigned ? "\(slot.displayName) 열기    \(slot.shortcut)" : "앱 미지정    \(slot.shortcut)")
            }
            .disabled(!slot.isAssigned || store.launching.contains(slot.id))
        }
        Divider()
        if !store.registrationErrors.isEmpty || store.settingsShortcutError != nil {
            if !store.registrationErrors.isEmpty {
                Text("앱 단축키 \(store.registrationErrors.count)개 등록 실패")
            }
            if let message = store.settingsShortcutErrorMessage { Text(message) }
            Button("단축키 다시 등록") { store.retryShortcuts() }
            Divider()
        }
        Button("설정…    ⌥ + ₩ / `", action: showSettings)
        Divider()
        Button("QuickLaunch 종료") { NSApplication.shared.terminate(nil) }
    }
}

private struct SettingsView: View {
    @ObservedObject var store: LauncherStore
    let chooseApp: (Int) -> Void

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("여덟 개의 앱, 바로 실행")
                        .font(.title2.weight(.semibold))
                    Text("Option + 1·2·3·4·Q·W·E·R에 각각 앱을 연결하세요.")
                        .foregroundStyle(.secondary)
                    Text("⌥ + ₩ / `로 설정 열기·숨기기 · Shift 없이 숫자 1 왼쪽 키")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                appColumn(Array(store.slots.prefix(4)))
                appColumn(Array(store.slots.suffix(4)))
            }

            if let notice = store.notice {
                Text(notice).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let message = store.settingsShortcutErrorMessage {
                Text(message).font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("단축키 다시 등록") { store.retryShortcuts() }
                Spacer()
                Button("기본값 복원") { store.restoreDefaults() }
            }
            Text("화면 맨 위 메뉴 막대의 번개 아이콘에서 다시 열 수 있습니다. 메뉴 막대가 붐비면 아이콘이 가려질 수 있으니, 앱을 다시 더블클릭해 설정을 여세요. 창을 닫아도 앱과 단축키는 계속 작동합니다.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("앱을 지정하지 않은 키는 가로채지 않습니다. 앱 선택은 즉시 저장·적용됩니다. 다른 앱과 단축키가 겹치면 해당 앱의 단축키를 바꾸고 다시 등록하세요.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        }
        .frame(width: 1000, height: 600)
    }

    private func appColumn(_ slots: [SlotConfiguration]) -> some View {
        VStack(spacing: 0) {
            ForEach(slots) { slot in
                appRow(slot)
                if slot.id != slots.last?.id { Divider().padding(.leading, 16) }
            }
        }
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
    }

    private func appRow(_ slot: SlotConfiguration) -> some View {
        let url = store.applicationURL(for: slot)
        return HStack(spacing: 12) {
            Text(slot.shortcut)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .frame(width: 44)
                .accessibilityLabel(slot.shortcutKey.accessibilityLabel)
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed").font(.system(size: 28))
                    .foregroundStyle(.secondary).frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.displayName).font(.body.weight(.medium)).lineLimit(1)
                if let message = store.registrationErrorMessage(for: slot.id) {
                    Text(message)
                        .font(.caption).foregroundStyle(.red)
                } else if !slot.isAssigned {
                    Text("앱 선택으로 연결하세요")
                        .font(.caption).foregroundStyle(.secondary)
                } else if url == nil {
                    Text("앱을 찾을 수 없습니다")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text("단축키 사용 가능").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("열기") { store.launch(slot.id) }
                .disabled(url == nil || store.launching.contains(slot.id))
                .accessibilityLabel("\(slot.displayName) 열기")
            Button("앱 선택…") { chooseApp(slot.id) }
                .accessibilityLabel("\(slot.shortcutKey.accessibilityLabel) 앱 선택")
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }
}
