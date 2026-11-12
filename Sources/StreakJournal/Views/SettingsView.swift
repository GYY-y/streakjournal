import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store

    @State private var confirmImport = false
    @State private var pendingImportURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                basicGroup
                dataGroup
            }
            .padding(24)
        }
        .confirmationDialog(
            L("导入数据将覆盖当前全部数据"),
            isPresented: $confirmImport,
            titleVisibility: .visible
        ) {
            Button(L("导入并覆盖"), role: .destructive) {
                if let url = pendingImportURL {
                    do { try store.importData(from: url) }
                    catch { store.lastMessage = LF("导入失败：%@", error.localizedDescription) }
                }
                pendingImportURL = nil
            }
        } message: {
            Text(L("导入会用文件中的数据替换当前的周期、破戒事件和每日记录。"))
        }
    }

    // MARK: - 基础

    private let goalOptions = [7, 14, 21, 30, 60, 90, 180, 365, 730]

    private var basicGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupHeader(text: L("应用"))
            SettingsGroup {
                SettingRow(icon: "target", color: .blue, title: L("坚持目标"), subtitle: L("只用于首页进度展示，不做强制判断")) {
                    Picker("", selection: Binding(
                        get: { store.goalDays },
                        set: { store.goalDays = $0 }
                    )) {
                        ForEach(goalOptions, id: \.self) { days in
                            Text(LF("%@ 天", "\(days)")).tag(days)
                        }
                        if !goalOptions.contains(store.goalDays) {
                            Text(LF("%@ 天（自定义）", "\(store.goalDays)")).tag(store.goalDays)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                    .labelsHidden()
                }
                RowDivider()
                SettingRow(icon: "circle.lefthalf.filled", color: .indigo, title: L("外观")) {
                    Picker("", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "appearance") ?? "system" },
                        set: { UserDefaults.standard.set($0, forKey: "appearance") }
                    )) {
                        Text(L("跟随系统")).tag("system")
                        Text(L("浅色")).tag("light")
                        Text(L("深色")).tag("dark")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .labelsHidden()
                }
                RowDivider()
                SettingRow(icon: "globe", color: .green, title: L("语言"), subtitle: L("选择语言后立即生效")) {
                    Picker("", selection: Binding(
                        get: { L10n.shared.lang },
                        set: { L10n.shared.lang = $0 }
                    )) {
                        Text("简体中文").tag(L10n.Lang.zhHans)
                        Text("繁體中文").tag(L10n.Lang.zhHant)
                        Text("English").tag(L10n.Lang.en)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .labelsHidden()
                }
                RowDivider()
                SettingRow(icon: "calendar.day.timeline.left", color: .teal, title: L("日期格式")) {
                    Picker("", selection: Binding(
                        get: { store.dateStyle },
                        set: { store.dateStyle = $0 }
                    )) {
                        ForEach(DateUtil.DateStyle.allCases) { style in
                            Text(style.rawValue).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - 数据

    private var dataGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupHeader(text: L("数据与维护"))
            SettingsGroup {
                SettingRow(icon: "square.and.arrow.up", color: .blue, title: L("导出数据"), subtitle: L("导出全部周期、破戒事件和每日记录（JSON 文件）")) {
                    PillButton(title: L("导出"), color: .blue) { exportData() }
                }
                RowDivider()
                SettingRow(icon: "square.and.arrow.down", color: .teal, title: L("导入数据"), subtitle: L("从导出的文件恢复记录（将覆盖当前数据）")) {
                    PillButton(title: L("导入"), color: .teal) { pickImportFile() }
                }
                RowDivider()
                SettingRow(icon: "externaldrive.badge.timemachine", color: .indigo, title: L("自动备份"), subtitle: L("系统每 12 小时自动备份一次（保留最近 10 份），备份文件存放在下方数据目录的 backups 文件夹中")) {
                    EmptyView()
                }
                RowDivider()

                SettingRow(icon: "folder", color: .yellow, title: L("数据目录"), subtitle: Database.dataDirectory.path) {
                    PillButton(title: L("打开"), color: .gray) {
                        NSWorkspace.shared.open(Database.dataDirectory)
                    }
                }
            }
        }
    }

    // MARK: - 面板

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "streakjournal-export-\(DateUtil.todayKey()).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try store.exportData(to: url) }
            catch { store.lastMessage = "导出失败：\(error.localizedDescription)" }
        }
    }

    private func pickImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            pendingImportURL = url
            confirmImport = true
        }
    }
}
