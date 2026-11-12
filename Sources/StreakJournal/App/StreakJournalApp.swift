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
                .task {
                    Store.shared.bootstrap()
                    StatusItemController.shared.installIfNeeded()
                }
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

/// 菜单栏面板：坚持天数速览 + 快捷操作
struct MenuBarPanel: View {
    @ObservedObject var store: Store

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
        .padding(10)
        .frame(width: 220)
        .buttonStyle(.plain)
    }

    private func activate(page: Page?) {
        if let page { AppNav.shared.page = page }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.height > 100 }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// 顶部菜单栏图标（NSStatusItem + NSPopover）
/// 注意：不放在 AppDelegate 的 applicationDidFinishLaunching 里，
/// 而是从主窗口的 .task 调用 installIfNeeded——swiftc 直编环境下
/// NSApplicationDelegateAdaptor 的生命周期回调不可靠，View 生命周期是确定会执行的。
final class StatusItemController: NSObject {
    static let shared = StatusItemController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var installed = false

    func installIfNeeded() {
        guard !installed else { return }
        installed = true

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            print("[StatusItem] 无法创建状态项按钮")
            return
        }

        if let path = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 18, height: 18)
            button.image = img
            print("[StatusItem] 使用打包图标 MenuBarIcon.png")
        } else {
            button.image = NSImage(systemSymbolName: "rosette", accessibilityDescription: "坚持记录")?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
            print("[StatusItem] 未找到 MenuBarIcon.png，使用 SF Symbol")
        }
        button.image?.isTemplate = false
        button.toolTip = "坚持记录"

        popover.contentViewController = NSHostingController(rootView: MenuBarPanel(store: Store.shared))
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 230, height: 210)

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        print("[StatusItem] 状态项已安装")
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let openItem = NSMenuItem(title: "打开主窗口", action: #selector(openMain), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
            let quitItem = NSMenuItem(title: "退出坚持记录", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            quitItem.target = NSApp
            menu.addItem(quitItem)
            if let button = statusItem?.button {
                statusItem?.menu = menu
                button.performClick(nil)
                statusItem?.menu = nil
            }
            return
        }
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openMain() {
        AppNav.shared.page = .home
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.height > 100 }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[App] applicationDidFinishLaunching")
        // 启动时按用户设置应用外观（跟随系统时为 nil）
        switch UserDefaults.standard.string(forKey: "appearance") ?? "system" {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
