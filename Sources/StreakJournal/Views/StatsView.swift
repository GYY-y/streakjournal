import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var store: Store

    enum Period: String, CaseIterable, Identifiable {
        case all = "全部"
        case week = "本周"
        case month = "本月"
        var id: String { rawValue }
    }

    @State private var period: Period = .all

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                statCards
                chartRow
                cycleRanking
                periodDetail
            }
            .padding(24)
        }
    }

    // MARK: 顶部时间筛选（参考图：分段胶囊）

    private var periodPicker: some View {
        HStack {
            Picker("", selection: $period) {
                ForEach(Period.allCases) { p in Text(p.rawValue).tag(p) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)
            Spacer()
        }
    }

    // MARK: 时间范围

    private var range: (start: String, end: String) {
        switch period {
        case .all:
            return ("0000-01-01", store.todayKey)
        case .week:
            return DateUtil.currentWeekRange()
        case .month:
            let m = DateUtil.monthKey(store.todayKey)
            return (m + "-01", DateUtil.addDays(DateUtil.addMonths(m, 1) + "-01", -1))
        }
    }

    private func inRange(_ date: String) -> Bool {
        (DateUtil.days(from: range.start, to: date) ?? -99) >= 0
            && (DateUtil.days(from: date, to: range.end) ?? -99) >= 0
    }

    // MARK: 彩色统计卡（参考图风格）

    private var statCards: some View {
        let inCycle = store.cycleDays()
        let persistDays: Int
        switch period {
        case .all: persistDays = store.summary.totalPersistDays
        case .week, .month: persistDays = inCycle.filter { inRange($0) }.count
        }
        let recordCount = store.records.filter { inRange($0.date) }.count
        let relapseCount = store.relapses.filter { inRange($0.date) }.count

        return HStack(spacing: 16) {
            ColoredStatCard(title: titlePrefix + "坚持天数", value: "\(persistDays)", color: .green, subtitle: subtitleFor(persistDays))
            ColoredStatCard(title: titlePrefix + "每日记录", value: "\(recordCount)", color: .blue, subtitle: "条记录")
            ColoredStatCard(title: titlePrefix + "破戒次数", value: "\(relapseCount)", color: .orange, subtitle: "破戒日独立保存，不计入坚持天数")
        }
    }

    private var titlePrefix: String {
        switch period {
        case .all: return "累计"
        case .week: return "本周"
        case .month: return "本月"
        }
    }

    private func subtitleFor(_ days: Int) -> String {
        switch period {
        case .all: return "含所有周期 · 当前坚持 \(store.summary.currentStreak) 天"
        case .week, .month: return "属于坚持周期的天数"
        }
    }

    // MARK: 图表区：柱状图 + 情绪排行

    private var chartRow: some View {
        HStack(alignment: .top, spacing: 16) {
            weeklyChart
            emotionRanking
        }
    }

    /// 每周坚持天数柱状图（过去 8 周，Swift Charts）
    private var weeklyChart: some View {
        let data = weeklyPersistData()
        return SectionCard(title: "每周坚持天数（过去 8 周）") {
            Chart(data, id: \.label) { item in
                BarMark(
                    x: .value("周", item.label),
                    y: .value("天", item.days)
                )
                .foregroundStyle(
                    LinearGradient(colors: [Color.accentColor.opacity(0.75), Color.accentColor], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .trailing)
            }
            .frame(height: 190)
        }
    }

    /// 情绪记录排行（横向进度条，参考图"常用应用"风格）
    private var emotionRanking: some View {
        let records = store.records.filter { inRange($0.date) }
        let tally = tallyEmotions(records)
        let maxCount = tally.first?.count ?? 1

        return SectionCard(title: "情绪记录排行") {
            if tally.isEmpty {
                Text("这个时间段还没有情绪记录。")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    ForEach(tally, id: \.key) { item in
                        StatBarRow(label: item.key, value: item.count, fraction: Double(item.count) / Double(max(maxCount, 1)), color: .purple, unit: " 次")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 周期排行（横向进度条）

    private var cycleRanking: some View {
        let cycles = store.cycles.sorted { $0.days > $1.days }
        let maxDays = max(cycles.first?.days ?? 1, 1)

        return SectionCard(title: "周期坚持天数排行") {
            if cycles.isEmpty {
                Text("还没有坚持周期。")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    ForEach(cycles) { c in
                        StatBarRow(
                            label: "\(DateUtil.display(c.startDate, style: store.dateStyle)) – \(c.endDate.map { DateUtil.display($0, style: store.dateStyle) } ?? "至今")" + (c.isActive ? "（进行中）" : ""),
                            value: c.days,
                            fraction: Double(c.days) / Double(maxDays),
                            color: c.isActive ? .green : .accentColor,
                            unit: " 天"
                        )
                    }
                }
            }
        }
    }

    // MARK: 时间段周期明细

    private var periodDetail: some View {
        let cycles = store.cycles
            .filter { overlaps($0, range.start, range.end) }
            .sorted { $0.startDate > $1.startDate }
        let relapses = store.relapses.filter { inRange($0.date) }
        let longest = cycles.map { $0.days }.max() ?? 0

        return SectionCard(title: "\(period.rawValue)周期明细 · 最长 \(longest) 天") {
            if cycles.isEmpty && relapses.isEmpty {
                Text("这个时间段没有周期和破戒记录。")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            if !cycles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(cycles) { c in
                        HStack {
                            Image(systemName: c.isActive ? "play.circle.fill" : "checkmark.circle")
                                .foregroundStyle(c.isActive ? Color.green : .secondary)
                            Text("\(DateUtil.display(c.startDate, style: store.dateStyle)) – \(c.endDate.map { DateUtil.display($0, style: store.dateStyle) } ?? "至今")")
                                .font(.system(size: 13).monospacedDigit())
                            Spacer()
                            Text("\(c.days) 天")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        }
                    }
                }
            }
            if !relapses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("破戒日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(relapses) { r in
                            Chip(text: DateUtil.display(r.date, style: store.dateStyle), selected: true, tint: .orange)
                        }
                    }
                }
                .padding(.top, cycles.isEmpty ? 0 : 8)
            }
        }
    }

    // MARK: 数据工具

    private struct WeekDatum {
        let label: String
        let days: Int
    }

    private func weeklyPersistData() -> [WeekDatum] {
        let inCycle = store.cycleDays()
        let calendar = Calendar.current
        var result: [WeekDatum] = []
        let today = Date()
        for offset in stride(from: 7, through: 0, by: -1) {
            guard let refDate = calendar.date(byAdding: .day, value: -7 * offset, to: today),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: refDate) else { continue }
            let startKey = DateUtil.key(interval.start)
            var days = 0
            for i in 0..<7 {
                let key = DateUtil.addDays(startKey, i)
                if key <= store.todayKey && inCycle.contains(key) { days += 1 }
            }
            let label = startKey.suffix(5).replacingOccurrences(of: "-", with: "/")
            result.append(WeekDatum(label: String(label), days: days))
        }
        return result
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
        return dict.sorted { $0.value > $1.value }.prefix(6).map { (key: $0.key, count: $0.value) }
    }
}
