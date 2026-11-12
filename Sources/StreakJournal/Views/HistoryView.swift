import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: Store

    enum Mode: String, CaseIterable, Identifiable {
        case calendar = "日历"
        case timeline = "时间线"
        case manage = "管理"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .calendar
    @State private var month = DateUtil.monthKey(DateUtil.todayKey())
    @State private var filterCycleID: Int64 = 0       // 0 = 全部
    @State private var filterRelapseOnly = false
    @State private var filterWithRecords = false
    @State private var selectedDate: DaySelection?
    @State private var expandedDays: Set<String> = []  // 时间线展开的日期，默认全部折叠

    // 管理模式（从设置页移入）
    @State private var editingCycle: Cycle?
    @State private var cycleToDelete: Cycle?
    @State private var relapseToDelete: RelapseEvent?
    @State private var adjustStart: Date = Date()
    @State private var showAdjustConfirm = false

    struct DaySelection: Identifiable {
        let day: String
        var id: String { day }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if mode == .calendar {
                calendarBody
            } else if mode == .timeline {
                timelineBody
            } else {
                manageBody
            }
        }
        .sheet(item: $selectedDate) { selection in
            RecordDetailSheet(date: selection.day)
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
            "确认调整当前周期开始日期",
            isPresented: $showAdjustConfirm,
            titleVisibility: .visible
        ) {
            Button("应用调整") {
                if let cycle = store.activeCycle {
                    var updated = cycle
                    updated.startDate = DateUtil.key(adjustStart)
                    store.updateCycle(updated)
                }
                showAdjustConfirm = false
            }
        } message: {
            Text("调整后坚持天数会按新日期重新计算。")
        }
    }

    // MARK: 工具栏

    private var toolbar: some View {
        HStack(spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            if mode == .calendar {
                monthNavigator
            } else if mode == .timeline {
                timelineFilters
            }
            Spacer()
        }
        .padding(14)
    }

    private var monthNavigator: some View {
        HStack(spacing: 8) {
            Button { month = DateUtil.addMonths(month, -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Text(DateUtil.displayMonth(month, style: store.dateStyle))
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
            Button { month = DateUtil.addMonths(month, 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .disabled(month >= DateUtil.monthKey(DateUtil.todayKey()))
            Button("本月") { month = DateUtil.monthKey(DateUtil.todayKey()) }
                .buttonStyle(.borderless)
        }
    }

    private var timelineFilters: some View {
        HStack(spacing: 10) {
            Picker("周期", selection: $filterCycleID) {
                Text("全部").tag(Int64(0))
                ForEach(Array(store.cycles.enumerated().reversed()), id: \.element.id) { index, cycle in
                    Text("第 \(store.cycles.count - index) 段 · \(cycle.startDate) 起 · \(cycle.days) 天")
                        .tag(cycle.id)
                }
            }
            .frame(width: 260)

            Toggle("破戒日", isOn: $filterRelapseOnly)
            Toggle("有记录", isOn: $filterWithRecords)
        }
        .font(.system(size: 13))
    }

    // MARK: 管理（周期与破戒，从设置页移入）

    private var manageBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
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
            .padding(24)
        }
    }

    // MARK: 日历

    private var calendarBody: some View {
        let grid = DateUtil.monthGrid(month)
        let relapses = store.relapseSet()
        let starts = store.cycleStartSet()
        let inCycle = store.cycleDays()
        let withRecord = store.recordSet()

        return ScrollView {
            VStack(spacing: 12) {
                HStack {
                    ForEach(weekdayHeaders, id: \.self) { w in
                        Text(w)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(0..<grid.blanks, id: \.self) { _ in
                        Color.clear.frame(height: 64)
                    }
                    ForEach(grid.days, id: \.self) { day in
                        CalendarCell(
                            day: day,
                            isToday: day == store.todayKey,
                            isFuture: day > store.todayKey,
                            hasRecord: withRecord.contains(day),
                            inCycle: inCycle.contains(day),
                            isRelapse: relapses.contains(day),
                            isCycleStart: starts.contains(day)
                        )
                        .onTapGesture { selectedDate = DaySelection(day: day) }
                    }
                }
                legend
            }
            .padding(20)
        }
    }

    private var weekdayHeaders: [String] { ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] }

    private var legend: some View {
        HStack(spacing: 16) {
            LegendDot(color: .accentColor, label: "周期开始")
            LegendDot(color: .green, label: "坚持中/坚持过")
            LegendDot(color: .orange, label: "破戒日")
            LegendDot(color: .secondary.opacity(0.5), label: "有记录")
            Text("未填写记录的日期不代表当天坚持成功。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: 时间线

    private var timelineBody: some View {
        let items = filteredRecords
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if items.isEmpty {
                    EmptyHint(icon: "tray", title: "没有符合条件的记录", detail: "调整筛选条件，或先去填写每日记录。")
                }
                ForEach(items) { r in
                    TimelineEntry(
                        record: r,
                        relapseNote: store.relapses.first { $0.date == r.date }?.note,
                        isExpanded: Binding(
                            get: { expandedDays.contains(r.date) },
                            set: { if $0 { expandedDays.insert(r.date) } else { expandedDays.remove(r.date) } }
                        )
                    )
                }
            }
            .padding(20)
        }
    }

    private var filteredRecords: [DailyRecord] {
        store.records.filter { r in
            if filterRelapseOnly && !store.relapseSet().contains(r.date) { return false }
            if filterWithRecords && r.freeText == nil && r.perception == nil && r.mood == nil && r.state == nil { return false }
            if filterCycleID != 0 {
                guard let cycle = store.cycles.first(where: { $0.id == filterCycleID }),
                      let d = DateUtil.days(from: cycle.startDate, to: r.date), d >= 0 else { return false }
                let end = cycle.endDate ?? store.todayKey
                if let e = DateUtil.days(from: r.date, to: end), e < 0 { return false }
            }
            return true
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

struct CalendarCell: View {
    let day: String
    let isToday: Bool
    let isFuture: Bool
    let hasRecord: Bool
    let inCycle: Bool
    let isRelapse: Bool
    let isCycleStart: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.system(size: 15, weight: isToday ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)
            HStack(spacing: 3) {
                if isCycleStart {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                }
                if isRelapse {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                }
                if hasRecord {
                    Circle().fill(Color.secondary.opacity(0.6)).frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cellBackground)
        .overlay(cellBorder)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(height: 64)
        .contentShape(Rectangle())
    }

    private var dayNumber: String {
        let parts = day.split(separator: "-")
        return parts.last.map(String.init) ?? day
    }

    private var textColor: Color {
        if isFuture { return .secondary.opacity(0.35) }
        if isRelapse { return .orange }
        return .primary
    }

    private var cellBackground: Color {
        if isRelapse { return Color.orange.opacity(0.10) }
        if isCycleStart { return Color.accentColor.opacity(0.10) }
        if inCycle { return Color.green.opacity(0.07) }
        return Color.primary.opacity(0.03)
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isToday ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isToday ? 1.5 : 1)
    }
}

/// 时间线卡片：默认折叠显示摘要，点击展开完整详情，再次点击折叠
struct TimelineEntry: View {
    let record: DailyRecord
    var relapseNote: String?
    @Binding var isExpanded: Bool

    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 摘要行（始终显示，点击切换展开/折叠）
            HStack(spacing: 8) {
                Text(DateUtil.display(record.date, style: store.dateStyle))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .textSelection(.enabled)
                Text(weekdayText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if relapseNote != nil {
                    Chip(text: "破戒日", selected: true, tint: .orange)
                }
                if let mood = record.mood { Chip(text: mood, selected: true) }
                ForEach(record.emotions.prefix(3), id: \.self) { e in
                    Chip(text: e, selected: true, tint: .purple)
                }
                if let state = record.state { Chip(text: state, selected: true, tint: .teal) }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }

            // 一行摘要（折叠时，点击同样可展开）
            if !isExpanded {
                Text(summaryLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    }
            }

            // 展开详情（文本可选中复制；顺序与每日记录一致：行为 → 感知 → 自由）
            if isExpanded {
                Divider()
                if !behaviorLines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日行为情况")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(behaviorLines, id: \.self) { line in
                            Text("· \(line)")
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                        }
                        if let note = record.behaviorNote {
                            Text("备注：\(note)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                if let p = record.perception, !p.isEmpty {
                    detailBlock("今日变化与感知", p)
                }
                if let text = record.freeText, !text.isEmpty {
                    detailBlock("自由记录", text)
                }
                if relapseNote != nil {
                    Text("破戒备注：\(relapseNote!)")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
                Text("最后更新：\(DateUtil.displayDateTime(record.updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isExpanded ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: 子视图与数据

    private func detailBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var summaryLine: String {
        if let text = record.freeText, !text.isEmpty { return text }
        if let p = record.perception, !p.isEmpty { return p }
        if let note = relapseNote { return "破戒备注：\(note)" }
        if record.mood != nil || !record.emotions.isEmpty || record.state != nil { return "（仅结构化记录）" }
        return "（点击展开查看详情）"
    }

    private var behaviorLines: [String] {
        var lines: [String] = []
        if let v = record.contactedPorn { lines.append("接触色情内容：\(v ? "是" : "否")") }
        if let v = record.targetBehavior { lines.append("发生目标行为：\(v ? "是" : "否")") }
        if let v = record.strongUrge { lines.append("出现明显冲动：\(v ? "是" : "否")") }
        return lines
    }

    private var weekdayText: String {
        guard let d = DateUtil.date(record.date) else { return "" }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[Calendar.current.component(.weekday, from: d) - 1]
    }
}
