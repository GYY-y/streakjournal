import SwiftUI

/// 关于页（独立顶部标签）
struct AboutView: View {
    @EnvironmentObject private var store: Store

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    Text("坚持记录")
                        .font(.system(size: 24, weight: .bold))
                    Text("StreakJournal v\(appVersion)")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("个人每日记录与坚持周期管理工具 · macOS 原生应用（Apple Silicon）")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)

                SettingsGroup {
                    SettingRow(icon: "book", color: .blue, title: "使用说明", subtitle: "每日记录自动保存，无需手动点击保存。") {
                        EmptyView()
                    }
                    RowDivider()
                    SettingRow(icon: "arrow.counterclockwise.circle", color: .green, title: "开启新周期", subtitle: "开启新周期只结束当前周期，之前的所有历史记录完整保留，不会删除。") {
                        EmptyView()
                    }
                    RowDivider()
                    SettingRow(icon: "exclamationmark.triangle", color: .orange, title: "破戒日", subtitle: "破戒日独立保存、不计入任何周期的坚持天数，可以在首页或设置中补录。") {
                        EmptyView()
                    }
                    RowDivider()
                    SettingRow(icon: "externaldrive", color: .indigo, title: "数据安全", subtitle: "全部数据保存在本机（\(Database.dataDirectory.path)），自动备份保留最近 10 份，支持导出与恢复。") {
                        EmptyView()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var appIcon: NSImage {
        if let icon = NSApp.applicationIconImage, icon.size.width > 1 { return icon }
        return NSImage(size: NSSize(width: 1, height: 1))
    }
}
