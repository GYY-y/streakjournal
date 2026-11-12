import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: Store

    @State private var editingCycle: Cycle?
    @State private var cycleToDelete: Cycle?
    @State private var relapseToDelete: RelapseEvent?
    @State private var backupToRestore: String?
    @State private var confirmImport = false
    @State private var pendingImportURL: URL?
    @State private var adjustStart: Date = Date()
    @State private var showAdjustConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                basicGroup
                cycleGroup
                dataGroup
            }
            .padding(24)
        }
        .sheet(item: $editingCycle) { cycle in
            CycleEditSheet(cycle: cycle)
        }
        .confirmationDialog(
            "确定删除这段周期吗？",
            isPresented: Binding(get: { cycleToDelete != nil }, set: { if !$0 { cycleToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除周期", role: .destructive) {
                if let c = cycleToDelete { store.deleteCycle(c) }
                cycleToDelete = nil
            }
        } message: {
            Text("删除周期不会删除每日记录和破戒事件，但对应的坚持天数统计会随之减少。")
        }
        .confirmationDialog(
            "确定删除这条破戒记录吗？",
            isPresented: Binding(get: { relapseToDelete != nil }, set: { if !$0 { relapseToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除破戒记录", role: .destructive) {
                if let r = relapseToDelete { store.deleteRelapse(r) }
                relapseToDelete = nil
            }
        } message: {
            Text("删除后对应的破戒日标记将从日历中消失。")
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

    // MARK: - 周期与破戒

    private var cycleGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupHeader(text: "周期与破戒")
            SettingsGroup {
                if let cycle = store.activeCycle {
                    SettingRow(icon: "flag.checkered", color: .green, title: "当前周期开始日期", subtitle: "调整后坚持天数会按新日期重新计算") {
                        CalendarDateField(date: $adjustStart, range: Date.distantPast...Date())
                        PillButton(title: "应用调整", color: .blue) { showAdjustConfirm = true }
                            .disabled(DateUtil.key(adjustStart) == cycle.startDate)
                    }
                    RowDivider()
                } else {
                    SettingRow(icon: "flag", color: .secondary.opacity(0.6), title: "当前没有进行中的周期", subtitle: "可以在首页开启第一个周期") {
                        EmptyView()
                    }
                    RowDivider()
                }

                ForEach(Array(store.cycles.enumerated().reversed()), id: \.element.id) { index, cycle in
                    SettingRow(
                        icon: cycle.isActive ? "play.circle.fill" : "checkmark.circle.fill",
                        color: cycle.isActive ? .green : .gray,
                        title: "第 \(store.cycles.count - index) 段 · \(DateUtil.display(cycle.startDate, style: store.dateStyle)) – \(cycle.endDate.map { DateUtil.display($0, style: store.dateStyle) } ?? "至今")",
                        subtitle: cycle.note
                    ) {
                        if cycle.isActive {
                            ValueText(text: "坚持中 · \(cycle.days) 天", color: .green)
                        } else {
                            ValueText(text: "\(cycle.days) 天", color: .secondary)
                        }
                        PillButton(title: "编辑", color: .gray) { editingCycle = cycle }
                        PillButton(title: "删除", color: .red) { cycleToDelete = cycle }
                    }
                    RowDivider()
                }

                ForEach(store.relapses) { r in
                    SettingRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "破戒日 · \(DateUtil.display(r.date, style: store.dateStyle))",
                        subtitle: r.note
                    ) {
                        PillButton(title: "删除", color: .red) { relapseToDelete = r }
                    }
                    RowDivider()
                }

                if store.cycles.isEmpty && store.relapses.isEmpty {
                    SettingRow(icon: "tray", color: .gray, title: "暂无周期与破戒记录") {
                        EmptyView()
                    }
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

/// 编辑周期（PRD 4.6 历史周期管理）
struct CycleEditSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State var cycle: Cycle
    @State private var hasEnd: Bool

    init(cycle: Cycle) {
        _cycle = State(initialValue: cycle)
        _hasEnd = State(initialValue: cycle.endDate != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑周期")
                .font(.title2.weight(.semibold))

            HStack(spacing: 12) {
                Text("开始日期")
                    .font(.system(size: 13))
                    .frame(width: 70, alignment: .leading)
                CalendarDateField(
                    date: Binding(
                        get: { DateUtil.date(cycle.startDate) ?? Date() },
                        set: { cycle.startDate = DateUtil.key($0) }
                    ),
                    range: Date.distantPast...Date()
                )
            }

            Toggle("设置结束日期", isOn: $hasEnd)
            if hasEnd {
                HStack(spacing: 12) {
                    Text("结束日期")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .leading)
                    CalendarDateField(
                        date: Binding(
                            get: { cycle.endDate.flatMap { DateUtil.date($0) } ?? Date() },
                            set: { cycle.endDate = DateUtil.key($0) }
                        ),
                        range: Date.distantPast...Date()
                    )
                }
            }

            Text("备注（可选）")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            NoteEditor(text: Binding(
                get: { cycle.note ?? "" },
                set: { cycle.note = $0.isEmpty ? nil : $0 }
            ), placeholder: "这段周期有什么想记下的？例如：心态变化、触发原因、目标调整……")

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    if !hasEnd { cycle.endDate = nil }
                    store.updateCycle(cycle)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
