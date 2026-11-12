import SwiftUI
import AppKit

@main
struct StreakJournalApp: App {
    @StateObject private var store = Store.shared
    @AppStorage("appearance") private var appearance: String = "system"
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear(perform: applyAppearance)
                .onChange(of: appearance) { _, _ in applyAppearance() }
                .frame(minWidth: 980, minHeight: 660)
                .task { Store.shared.bootstrap() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("手动备份") { Store.shared.manualBackup() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
    }

    /// 用 NSApp.appearance 控制主题：从固定主题切回"跟随系统"时设为 nil 即可恢复系统外观，
    /// 避免 preferredColorScheme(nil) 在 macOS 上无法还原的问题。
    private func applyAppearance() {
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动时按用户设置应用外观（跟随系统时为 nil）
        switch UserDefaults.standard.string(forKey: "appearance") ?? "system" {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
