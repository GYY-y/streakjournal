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
            } else {
                timelineBody
            }
        }
        .navigationTitle("历史记录")
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
            LazyVStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    EmptyHint(icon: "tray", title: "没有符合条件的记录", detail: "调整筛选条件，或先去填写每日记录。")
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, r in
                    TimelineEntry(
                        record: r,
                        relapseNote: store.relapses.first { $0.date == r.date }?.note,
                        isFirst: index == 0,
                        isLast: index == items.count - 1
                    )
                    .onTapGesture { selectedDate = DaySelection(day: r.date) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
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

/// 时间线单条目：日期列 + 竖线圆点 + 内容
struct TimelineEntry: View {
    let record: DailyRecord
    var relapseNote: String?
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 左：日期列
            VStack(alignment: .leading, spacing: 2) {
                Text(DateUtil.display(record.date, style: store.dateStyle))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                Text(weekdayText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 92, alignment: .leading)
            .padding(.top, 2)

            // 中：竖线 + 圆点
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle().fill(lineColor).frame(width: 2).frame(maxHeight: .infinity)
                } else {
                    Color.clear.frame(width: 2, height: 10)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(Color(nsColor: .controlBackgroundColor), lineWidth: 2))
                if !isLast {
                    Rectangle().fill(lineColor).frame(width: 2).frame(maxHeight: .infinity)
                } else {
                    Color.clear.frame(width: 2, height: 10)
                }
            }
            .frame(width: 16)

            // 右：内容
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if relapseNote != nil {
                        Chip(text: "破戒日", selected: true, tint: .orange)
                    }
                    if let mood = record.mood { Chip(text: "心态 \(mood)", selected: true) }
                    ForEach(record.emotions.prefix(3), id: \.self) { e in
                        Chip(text: e, selected: true, tint: .purple)
                    }
                    if let state = record.state { Chip(text: state, selected: true, tint: .teal) }
                }
                if let text = record.freeText, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if let p = record.perception, !p.isEmpty {
                    Text(p)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 18)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @EnvironmentObject private var store: Store

    private var lineColor: Color { Color.primary.opacity(0.10) }

    private var dotColor: Color {
        if relapseNote != nil { return .orange }
        if record.mood != nil || !record.emotions.isEmpty { return Color.accentColor }
        return .secondary.opacity(0.5)
    }

    private var weekdayText: String {
        guard let d = DateUtil.date(record.date) else { return "" }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[Calendar.current.component(.weekday, from: d) - 1]
    }
}
