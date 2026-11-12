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

        // Mac 顶部菜单栏图标 + 快捷面板
        MenuBarExtra {
            MenuBarPanel(store: store)
        } label: {
            Image(nsImage: MenuBarPanel.loadMenuIcon())
        }
        .menuBarExtraStyle(.window)
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

/// 菜单栏下拉面板：坚持天数速览 + 快捷操作
struct MenuBarPanel: View {
    @ObservedObject var store: Store

    static func loadMenuIcon() -> NSImage {
        if let path = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        // 兜底：SF Symbol 小恐龙风格图形
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let img = NSImage(systemSymbolName: "rosette", accessibilityDescription: "坚持记录")?
            .withSymbolConfiguration(cfg) ?? NSImage()
        return img
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text(store.activeCycle != nil ? "已坚持 \(store.currentStreak) 天" : "还没有进行中的周期")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 8) {
                if store.hasRecordToday {
                    Label("今天已记录", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                } else {
                    Label("今天还没有记录", systemImage: "circle.dashed")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            Button("打开主窗口") { activate(page: nil) }
            Button("填写今日记录") { activate(page: .record) }
            Button("查看勋章墙") { activate(page: .badges) }
            Button("手动备份") { store.manualBackup() }

            Divider()

            Button("退出坚持记录") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 220)
        .buttonStyle(.plain)
    }

    private func activate(page: Page?) {
        if let page { AppNav.shared.page = page }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "坚持记录" || $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
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
