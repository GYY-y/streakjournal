import SwiftUI
import AppKit
import UserNotifications
import Combine

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
                    NotificationManager.shared.setup()
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

/// 顶部菜单栏图标（NSStatusItem + 原生 NSMenu）
/// 点击直接弹出系统原生菜单：无动画、系统渲染、悬停高亮，和系统菜单观感完全一致。
/// 注意：不放在 AppDelegate 的 applicationDidFinishLaunching 里，
/// 而是从主窗口的 .task 调用 installIfNeeded——swiftc 直编环境下
/// NSApplicationDelegateAdaptor 的生命周期回调不可靠，View 生命周期是确定会执行的。
final class StatusItemController: NSObject, NSMenuDelegate {
    static let shared = StatusItemController()
    private var statusItem: NSStatusItem?
    private var installed = false
    /// 信息行数值右对齐的制表位位置
    private let valueTab: CGFloat = 190

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
            button.image = NSImage(systemSymbolName: "rosette", accessibilityDescription: "循迹")?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
            print("[StatusItem] 未找到 MenuBarIcon.png，使用 SF Symbol")
        }
        button.image?.isTemplate = false
        button.toolTip = "循迹"

        // 原生菜单：menu 属性直接挂在状态项上，左键/右键点击都弹出系统菜单
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        statusItem = item
        print("[StatusItem] 状态项已安装（原生 NSMenu）")
    }

    // MARK: - 菜单内容：每次打开时重建（语言/数据始终最新）

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let store = Store.shared

        // 状态区（灰色信息行，不可点击）
        menu.addItem(infoItem(label: L("已坚持"),
                              value: store.activeCycle != nil ? LF("%@ 天", "\(store.currentStreak)") : L("未开始")))
        let recorded = store.hasRecordToday
        menu.addItem(infoItem(label: L("今日记录"),
                              value: recorded ? L("已记录") : L("今天还没记录"),
                              valueColor: recorded ? .systemGreen : .systemRed))

        menu.addItem(.separator())

        menu.addItem(actionItem(title: L("打开主窗口"), key: nil, action: #selector(openMain)))
        menu.addItem(actionItem(title: L("设置"), key: ",", action: #selector(openSettings)))

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L("退出"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// 信息行：标签左、数值右（右对齐制表位），不可点击
    private func infoItem(label: String, value: String, valueColor: NSColor = .secondaryLabelColor) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false

        let para = NSMutableParagraphStyle()
        para.tabStops = [NSTextTab(textAlignment: .right, location: valueTab)]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 13), .foregroundColor: NSColor.labelColor, .paragraphStyle: para
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 13), .foregroundColor: valueColor, .paragraphStyle: para
        ]
        let s = NSMutableAttributedString(string: label, attributes: labelAttrs)
        s.append(NSAttributedString(string: "\t"))
        s.append(NSAttributedString(string: value, attributes: valueAttrs))
        item.attributedTitle = s
        return item
    }

    /// 动作项：原生样式，可选快捷键
    private func actionItem(title: String, key: String?, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key ?? "")
        item.target = self
        item.keyEquivalentModifierMask = .command
        return item
    }

    @objc private func openMain() {
        AppNav.shared.page = .home
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.height > 100 }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettings() {
        AppNav.shared.page = .settings
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

// MARK: - 每日语录通知：每天固定时间用系统通知推送一句哲学语录（本地通知，无需网络）

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let dailyID = "dailyPhilosophyQuote"
    /// 每天推送时刻（本地时间）：上午 9:00
    private let hour = 9
    private let minute = 0
    private var langCancellable: AnyCancellable?

    private override init() { super.init() }

    func setup() {
        center.delegate = self
        // 语言切换后按新语言重新安排通知内容
        langCancellable = L10n.shared.$lang
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleDailyQuote() }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted else {
                print("[Notify] 用户未授权通知")
                return
            }
            DispatchQueue.main.async { self?.scheduleDailyQuote() }
        }
    }

    /// （重新）安排每日通知：每次启动换一句新语录，系统重复触发
    func scheduleDailyQuote() {
        let q = Quotes.random()
        let r = L10n.shared.resolved
        let content = UNMutableNotificationContent()
        content.title = L("循迹")
        content.body = "「\(q.text(r))」 ——\(q.author(r))"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        center.add(UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)) { error in
            if let error { print("[Notify] 安排失败:", error.localizedDescription) }
            else { print("[Notify] 每日语录通知已安排（每天 \(self.hour):\(String(format: "%02d", self.minute))）") }
        }
    }

    /// 应用在前台时也显示横幅（默认前台不展示）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
