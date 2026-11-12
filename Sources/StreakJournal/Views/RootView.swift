import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case home = "首页"
    case record = "每日记录"
    case history = "统计"
    case badges = "勋章"
    case settings = "设置"
    case about = "关于"

    var icon: String {
        switch self {
        case .home: return "figure.mind.and.body"
        case .record: return "square.and.pencil"
        case .history: return "chart.bar.xaxis"
        case .badges: return "rosette"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    /// 显示名（随语言切换）
    var title: String { L(rawValue) }

    var id: String { rawValue }
}

/// 页面导航状态：供子视图切换页面；记住上次停留的页面；全局单例（菜单栏面板也要切换页面）
final class AppNav: ObservableObject {
    static let shared = AppNav()
    @Published var page: Page = Page(rawValue: UserDefaults.standard.string(forKey: "lastPage") ?? "") ?? .home
    private init() {}
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var nav = AppNav.shared
    /// 观察语言变化：切换语言时整个页面树重新渲染
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(L("坚持记录"))
        .onChange(of: nav.page) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: "lastPage")
        }
        .environmentObject(nav)
        .overlay(alignment: .top) {
            if let msg = store.lastMessage {
                ToastBanner(text: msg)
                    .padding(.top, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { store.lastMessage = nil }
                    }
                    .onTapGesture { withAnimation { store.lastMessage = nil } }
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.lastMessage)
    }

    // MARK: 顶部标签栏：居中胶囊分段（标题固定显示在窗口最顶部中间）

    private var topBar: some View {
        VStack(spacing: 0) {
            Picker("", selection: $nav.page) {
                ForEach(Page.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 560)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch nav.page {
        case .home: HomeView()
        case .record: RecordView()
        case .history: HistoryView()
        case .badges: BadgesView()
        case .settings: SettingsView()
        case .about: AboutView()
        }
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.system(size: 13))
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)).shadow(color: .black.opacity(0.15), radius: 8, y: 2))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}
