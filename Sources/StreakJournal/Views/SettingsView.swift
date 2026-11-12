import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store

    @State private var backupToRestore: String?
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
            "恢复备份将覆盖当前全部数据",
            isPresented: Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("恢复备份", role: .destructive) {
                if let name = backupToRestore { store.restoreBackup(fileName: name) }
                backupToRestore = nil
            }
        } message: {
            Text("恢复「\(backupToRestore ?? "")」会用备份内容覆盖当前的周期、破戒事件和每日记录。")
        }
        .confirmationDialog(
            "导入数据将覆盖当前全部数据",
            isPresented: $confirmImport,
            titleVisibility: .visible
        ) {
            Button("导入并覆盖", role: .destructive) {
                if let url = pendingImportURL {
                    do { try store.importData(from: url) }
                    catch { store.lastMessage = "导入失败：\(error.localizedDescription)" }
                }
                pendingImportURL = nil
            }
        } message: {
            Text("导入会用文件中的数据替换当前的周期、破戒事件和每日记录。")
        }
    }

    // MARK: - 基础

    private let goalOptions = [7, 14, 21, 30, 60, 90, 180, 365, 730]

    private var basicGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupHeader(text: "应用")
            SettingsGroup {
                SettingRow(icon: "target", color: .blue, title: "坚持目标", subtitle: "只用于首页进度展示，不做强制判断") {
                    Picker("", selection: Binding(
                        get: { store.goalDays },
                        set: { store.goalDays = $0 }
                    )) {
                        ForEach(goalOptions, id: \.self) { days in
                            Text("\(days) 天").tag(days)
                        }
                        if !goalOptions.contains(store.goalDays) {
                            Text("\(store.goalDays) 天（自定义）").tag(store.goalDays)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                    .labelsHidden()
                }
                RowDivider()
                SettingRow(icon: "circle.lefthalf.filled", color: .indigo, title: "外观") {
                    Picker("", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "appearance") ?? "system" },
                        set: { UserDefaults.standard.set($0, forKey: "appearance") }
                    )) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .labelsHidden()
                }
                RowDivider()
                SettingRow(icon: "calendar.day.timeline.left", color: .teal, title: "日期格式") {
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
        let backups = Store.backupFiles()
        return VStack(alignment: .leading, spacing: 8) {
            GroupHeader(text: "数据与维护")
            SettingsGroup {
                SettingRow(icon: "square.and.arrow.up", color: .blue, title: "导出数据", subtitle: "导出全部周期、破戒事件和每日记录（JSON 文件）") {
                    PillButton(title: "导出", color: .blue) { exportData() }
                }
                RowDivider()
                SettingRow(icon: "square.and.arrow.down", color: .teal, title: "导入数据", subtitle: "从导出的文件恢复记录（将覆盖当前数据）") {
                    PillButton(title: "导入", color: .teal) { pickImportFile() }
                }
                RowDivider()
                if backups.isEmpty {
                    SettingRow(icon: "externaldrive.badge.timemachine", color: .indigo, title: "手动备份", subtitle: "还没有备份文件，点击右侧创建第一份") {
                        PillButton(title: "备份", color: .green) { store.manualBackup() }
                    }
                    RowDivider()
                } else {
                    SettingRow(icon: "externaldrive.badge.timemachine", color: .indigo, title: "备份记录", subtitle: "共 \(backups.count) 份（自动备份超过 24 小时一次，保留最近 10 份），点击备份可恢复") {
                        Menu {
                            ForEach(backups, id: \.lastPathComponent) { url in
                                Button {
                                    backupToRestore = url.lastPathComponent
                                } label: {
                                    Text(backupLabel(url))
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text("选择恢复")
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.orange))
                            .foregroundStyle(.white)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    RowDivider()
                }

                SettingRow(icon: "folder", color: .yellow, title: "数据目录", subtitle: Database.dataDirectory.path) {
                    PillButton(title: "打开", color: .gray) {
                        NSWorkspace.shared.open(Database.dataDirectory)
                    }
                }
            }
        }
    }

    // MARK: - 面板

    private func backupLabel(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int
        let sizeText = size.map { " · \(max(1, $0 / 1024)) KB" } ?? ""
        return url.lastPathComponent + sizeText
    }

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
