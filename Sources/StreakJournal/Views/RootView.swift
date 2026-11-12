import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case home = "首页"
    case record = "每日记录"
    case history = "历史记录"
    case stats = "统计"
    case settings = "设置"

    var icon: String {
        switch self {
        case .home: return "figure.mind.and.body"
        case .record: return "square.and.pencil"
        case .history: return "clock.arrow.circlepath"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }

    var id: String { rawValue }
}

/// 页面导航状态：供子视图切换页面
final class AppNav: ObservableObject {
    @Published var page: Page = .home
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @StateObject private var nav = AppNav()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environmentObject(nav)
        .overlay(alignment: .top) {
            if let msg = store.lastMessage {
                ToastBanner(text: msg)
                    .padding(.top, 46)
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

    // MARK: 顶部标签栏（参考图风格：居中胶囊分段）

    private var topBar: some View {
        HStack {
            Text("坚持记录")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $nav.page) {
                ForEach(Page.allCases) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 480)
            Spacer()
            // 等宽占位，让标签真正居中
            Text("坚持记录")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.clear)
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
        case .stats: StatsView()
        case .settings: SettingsView()
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
