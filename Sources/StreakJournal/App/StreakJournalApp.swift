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

/// 菜单栏刷新通知：每次点开状态项图标时，面板重新抽一句语录
extension Notification.Name {
    static let menuBarPanelWillShow = Notification.Name("menuBarPanelWillShow")
}

/// 菜单栏面板：仿原生菜单样式（标签左、数值右）+ 一句哲学语录
struct MenuBarPanel: View {
    @ObservedObject var store: Store
    @ObservedObject private var l10n = L10n.shared
    @State private var hoveredAction: String?
    @State private var quote = Quotes.random()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 状态区（不可点击）
            menuRow(label: L("已坚持"), value: store.activeCycle != nil ? LF("%@ 天", "\(store.currentStreak)") : L("未开始"))

            HStack(spacing: 0) {
                Text(L("今日记录"))
                    .font(.system(size: 13))
                Spacer()
                if store.hasRecordToday {
                    Text(L("已记录"))
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                } else {
                    Text(L("今天还没记录"))
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            // 哲学语录：每次点开菜单栏换一句
            VStack(alignment: .leading, spacing: 2) {
                Text("「\(quote.text(l10n.resolved))」")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("—— \(quote.author(l10n.resolved))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().padding(.vertical, 4)

            actionButton(L("打开主窗口"), key: "open") { activate(page: nil) }
            actionButton(L("设置"), key: "settings") { activate(page: .settings) }

            Divider().padding(.vertical, 4)

            actionButton(L("退出"), key: "quit") { NSApp.terminate(nil) }
        }
        .padding(.vertical, 6)
        .frame(width: 250)
        .onAppear { quote = Quotes.random() }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarPanelWillShow)) { _ in
            quote = Quotes.random()
        }
    }

    private func menuRow(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private func actionButton(_ title: String, key: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(hoveredAction == key ? Color.accentColor.opacity(0.15) : .clear)
        )
        .onHover { hovering in
            hoveredAction = hovering ? key : (hoveredAction == key ? nil : hoveredAction)
        }
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
        popover.contentSize = NSSize(width: 250, height: 280)

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        print("[StatusItem] 状态项已安装")
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let openItem = NSMenuItem(title: L("打开主窗口"), action: #selector(openMain), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
            let quitItem = NSMenuItem(title: L("退出"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
            NotificationCenter.default.post(name: .menuBarPanelWillShow, object: nil)
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
