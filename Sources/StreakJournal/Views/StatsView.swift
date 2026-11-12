import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: Store
    @State private var selectedMonth = DateUtil.monthKey(DateUtil.todayKey())

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                basicStats
                weeklySummary
                monthlySummary
            }
            .padding(24)
        }
        .navigationTitle("统计")
    }

    // MARK: 基础统计（PRD 4.5.1）

    private var basicStats: some View {
        let s = store.summary
        return SectionCard(title: "基础统计") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                StatCard(title: "当前坚持天数", value: "\(s.currentStreak)")
                StatCard(title: "历史最长坚持", value: "\(s.longestStreak)", subtitle: "天")
                StatCard(title: "坚持周期总数", value: "\(s.totalCycles)", subtitle: "段")
                StatCard(title: "累计坚持天数", value: "\(s.totalPersistDays)", subtitle: "天（含所有周期）")
                StatCard(title: "历史破戒次数", value: "\(s.relapseCount)", subtitle: "次")
                StatCard(title: "每日记录", value: "\(s.recordCount)", subtitle: "条")
            }
        }
    }

    // MARK: 周度汇总（PRD 4.5.2）

    private var weeklySummary: some View {
        let week = DateUtil.currentWeekRange()
        let weekRecords = store.records.filter {
            (DateUtil.days(from: week.start, to: $0.date) ?? -1) >= 0 && (DateUtil.days(from: $0.date, to: week.end) ?? -1) >= 0
        }
        let inCycle = store.cycleDays()
        let weekPersistDays = weekDays(week.start, week.end).filter { inCycle.contains($0) }.count
        let weekCycles = store.cycles.filter { overlaps($0, week.start, week.end) }
        let emotionTally = tallyEmotions(weekRecords)

        return SectionCard(title: "本周汇总（\(DateUtil.display(week.start, style: store.dateStyle)) – \(DateUtil.display(week.end, style: store.dateStyle))）") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                StatCard(title: "本周每日记录", value: "\(weekRecords.count)", subtitle: "条")
                StatCard(title: "本周坚持天数", value: "\(weekPersistDays)", subtitle: "天（属于周期）")
                StatCard(title: "本周经历周期", value: "\(weekCycles.count)", subtitle: "段")
            }
            if emotionTally.isEmpty {
                Text("本周还没有情绪记录。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 6) {
                    ForEach(emotionTally, id: \.key) { item in
                        Chip(text: "\(item.key) ×\(item.count)", selected: true, tint: .purple)
                    }
                }
            }
        }
    }

    // MARK: 月度汇总（PRD 4.5.3）

    private var monthlySummary: some View {
        let monthStart = selectedMonth + "-01"
        let monthEnd = DateUtil.addDays(DateUtil.addMonths(selectedMonth, 1) + "-01", -1)
        let monthRelapses = store.relapses.filter {
            DateUtil.monthKey($0.date) == selectedMonth
        }
        let monthRecords = store.records.filter { DateUtil.monthKey($0.date) == selectedMonth }
        let monthCycles = store.cycles.filter { overlaps($0, monthStart, monthEnd) }
        let longestInMonth = monthCycles.map { $0.days }.max() ?? 0

        return SectionCard(title: "月度汇总") {
            HStack {
                Button { selectedMonth = DateUtil.addMonths(selectedMonth, -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text(DateUtil.displayMonth(selectedMonth, style: store.dateStyle))
                    .font(.system(size: 14, weight: .medium))
                Button { selectedMonth = DateUtil.addMonths(selectedMonth, 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(selectedMonth >= DateUtil.monthKey(DateUtil.todayKey()))
                Button("本月") { selectedMonth = DateUtil.monthKey(DateUtil.todayKey()) }
                    .buttonStyle(.borderless)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                StatCard(title: "本月周期", value: "\(monthCycles.count)", subtitle: "段")
                StatCard(title: "本月破戒", value: "\(monthRelapses.count)", subtitle: "次")
                StatCard(title: "本月最长周期", value: "\(longestInMonth)", subtitle: "天")
            }

            if monthCycles.isEmpty {
                Text("本月没有坚持周期。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(monthCycles) { c in
                        HStack {
                            Image(systemName: c.isActive ? "play.circle.fill" : "checkmark.circle")
                                .foregroundStyle(c.isActive ? Color.accentColor : .secondary)
                            Text("\(DateUtil.display(c.startDate, style: store.dateStyle)) – \(c.endDate.map { DateUtil.display($0, style: store.dateStyle) } ?? "至今")")
                                .font(.system(size: 13).monospacedDigit())
                            Spacer()
                            Text("\(c.days) 天")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        }
                    }
                }
            }

            if !monthRelapses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月破戒日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(monthRelapses) { r in
                            Chip(text: DateUtil.display(r.date, style: store.dateStyle), selected: true, tint: .orange)
                        }
                    }
                }
            }

            Text("本月每日记录：\(monthRecords.count) 条")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 工具

    private func weekDays(_ start: String, _ end: String) -> [String] {
        guard let d = DateUtil.days(from: start, to: end), d >= 0 else { return [] }
        return (0...d).map { DateUtil.addDays(start, $0) }
    }

    private func overlaps(_ cycle: Cycle, _ start: String, _ end: String) -> Bool {
        let cycleEnd = cycle.endDate ?? end
        let afterStart = (DateUtil.days(from: cycle.startDate, to: end) ?? -1) >= 0
        let beforeEnd = (DateUtil.days(from: start, to: cycleEnd) ?? -1) >= 0
        return afterStart && beforeEnd
    }

    private func tallyEmotions(_ records: [DailyRecord]) -> [(key: String, count: Int)] {
        var dict: [String: Int] = [:]
        for r in records {
            for e in r.emotions { dict[e, default: 0] += 1 }
        }
        return dict.sorted { $0.value > $1.value }.prefix(8).map { (key: $0.key, count: $0.value) }
    }
}
