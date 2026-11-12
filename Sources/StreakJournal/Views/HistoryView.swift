import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: Store

    enum Mode: String, CaseIterable, Identifiable {
        case calendar = "日历"
        case timeline = "时间线"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .calendar
    @State private var month = DateUtil.monthKey(DateUtil.todayKey())
    @State private var filterCycleID: Int64 = 0       // 0 = 全部
    @State private var filterRelapseOnly = false
    @State private var filterWithRecords = false
    @State private var selectedDate: DaySelection?
    @State private var expandedDays: Set<String> = []  // 时间线展开的日期，默认全部折叠

    struct DaySelection: Identifiable {
        let day: String
        var id: String { day }
    }

    // MARK: 周期配色：同周期同色，不同周期不同色

    private let cyclePalette: [Color] = [.blue, .purple, .teal, .indigo, .pink, .mint, .cyan, .brown]

    /// 某天所属周期的颜色（不属于任何周期返回 nil）
    private func cycleColor(for day: String) -> Color? {
        cycleIndex(for: day).map { cyclePalette[$0 % cyclePalette.count] }
    }

    /// 某天所属周期的展示序号（第 N 段，从 1 开始；不属于任何周期返回 nil）
    private func cycleIndex(for day: String) -> Int? {
        for (i, c) in store.cycles.enumerated() {
            guard let d = DateUtil.days(from: c.startDate, to: day), d >= 0 else { continue }
            let end = c.endDate ?? store.todayKey
            if let e = DateUtil.days(from: day, to: end), e >= 0 {
                return store.cycles.count - i
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if mode == .calendar {
                calendarBody
            } else {
                timelineBody
            }
        }
        .sheet(item: $selectedDate) { selection in
            RecordDetailSheet(date: selection.day)
        }
    }

    // MARK: 工具栏

    private var toolbar: some View {
        HStack(spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            if mode == .calendar {
                monthNavigator
            } else {
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

    // MARK: 日历

    private var calendarBody: some View {
        let grid = DateUtil.monthGrid(month)
        let relapses = store.relapseSet()
        let starts = store.cycleStartSet()
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
                            isRelapse: relapses.contains(day),
                            isCycleStart: starts.contains(day),
                            cycleColor: cycleColor(for: day)
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
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(Color.blue.opacity(0.18)).frame(width: 10, height: 10)
                Text("周期日（同周期同色）")
            }
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("有记录")
            }
            LegendDot(color: .red, label: "破戒日（警告）")
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
                        cycleColor: cycleColor(for: r.date),
                        cycleLabel: cycleIndex(for: r.date).map { "第 \($0) 段" },
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
    let isRelapse: Bool
    let isCycleStart: Bool
    var cycleColor: Color? = nil

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
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
                if hasRecord {
                    // 有记录：插画图标（绿色对勾）
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }
            .frame(height: 10)
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
        if isRelapse { return .red }
        return .primary
    }

    private var cellBackground: Color {
        // 破戒日：红色警告
        if isRelapse { return Color.red.opacity(0.12) }
        // 周期日：同周期同色，不同周期不同色
        if let cc = cycleColor { return cc.opacity(0.14) }
        return Color.primary.opacity(0.03)
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isToday ? Color.accentColor : (cycleColor ?? Color.primary.opacity(0.06)).opacity(0.35),
                lineWidth: isToday ? 1.5 : 1
            )
    }
}

/// 时间线卡片：按周期着色（同周期同色），默认折叠，点击头部展开，详情可选中复制
struct TimelineEntry: View {
    let record: DailyRecord
    var relapseNote: String?
    var cycleColor: Color? = nil
    var cycleLabel: String? = nil
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
                if let cycleLabel {
                    Chip(text: cycleLabel, selected: true, tint: cycleColor ?? .accentColor)
                }
                if relapseNote != nil {
                    Chip(text: "破戒日", selected: true, tint: .red)
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
                        .foregroundStyle(.red)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
    }

    // MARK: 子视图与数据

    /// 破戒日用红色警告底色；否则按周期底色着色
    private var cardBackground: Color {
        if relapseNote != nil { return Color.red.opacity(0.07) }
        if let cc = cycleColor { return cc.opacity(0.08) }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var cardBorder: Color {
        if relapseNote != nil { return Color.red.opacity(0.30) }
        if let cc = cycleColor { return cc.opacity(0.30) }
        return Color.primary.opacity(0.08)
    }

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
