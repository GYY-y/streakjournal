import Foundation

enum DateUtil {
    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static let timeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        return f
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    static func date(_ key: String) -> Date? { keyFormatter.date(from: key) }

    static func now() -> String { timeFormatter.string(from: Date()) }

    static func startOfDay(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    /// b - a 的天数差（按自然日）
    static func days(from a: String, to b: String) -> Int? {
        guard let da = date(a), let db = date(b) else { return nil }
        return Calendar.current.dateComponents([.day], from: startOfDay(da), to: startOfDay(db)).day
    }

    static func addDays(_ dayKey: String, _ n: Int) -> String {
        guard let d = date(dayKey),
              let nd = Calendar.current.date(byAdding: .day, value: n, to: d) else { return dayKey }
        return Self.key(nd)
    }

    static func todayKey() -> String { key(Date()) }

    /// 月份键，如 "2026-11"
    static func monthKey(_ dayKey: String) -> String { String(dayKey.prefix(7)) }

    static func addMonths(_ month: String, _ n: Int) -> String {
        guard let d = date(month + "-01"),
              let nd = Calendar.current.date(byAdding: .month, value: n, to: d) else { return month }
        return Self.monthKey(Self.key(nd))
    }

    /// 周一为一周起点，返回本周周一与周日的 key
    static func currentWeekRange() -> (start: String, end: String) {
        let cal = Calendar.current
        let today = startOfDay(Date())
        guard let weekday = cal.dateComponents([.weekday], from: today).weekday else {
            let k = key(today); return (k, k)
        }
        // weekday: 1=周日, 2=周一 ... 7=周六
        let offsetToMonday = (weekday == 1) ? -6 : (2 - weekday)
        guard let monday = cal.date(byAdding: .day, value: offsetToMonday, to: today),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else {
            let k = key(today); return (k, k)
        }
        return (key(monday), key(sunday))
    }

    /// 日历网格：返回该月所有日期 key（含前后补齐的空位信息）
    static func monthGrid(_ monthKey: String) -> (blanks: Int, days: [String]) {
        guard let first = date(monthKey + "-01"),
              let range = Calendar.current.range(of: .day, in: .month, for: first) else {
            return (0, [])
        }
        let weekday = Calendar.current.component(.weekday, from: first)
        let blanks = (weekday == 1) ? 6 : (weekday - 2)   // 周一为首列
        var days: [String] = []
        for d in range {
            var comps = Calendar.current.dateComponents([.year, .month], from: first)
            comps.day = d
            if let dd = Calendar.current.date(from: comps) {
                days.append(key(dd))
            }
        }
        return (blanks, days)
    }

    // MARK: 显示格式

    enum DateStyle: String, CaseIterable, Identifiable {
        case iso = "2026-11-11"
        case chinese = "2026年11月11日"
        var id: String { rawValue }
    }

    static func display(_ dayKey: String, style: String) -> String {
        let parts = dayKey.split(separator: "-").map(String.init)
        guard parts.count == 3 else { return dayKey }
        switch style {
        case DateStyle.chinese.rawValue:
            return "\(parts[0])年\(Int(parts[1]) ?? 0)月\(Int(parts[2]) ?? 0)日"
        default:
            return dayKey
        }
    }

    static func displayMonth(_ monthKey: String, style: String) -> String {
        let parts = monthKey.split(separator: "-").map(String.init)
        guard parts.count == 2 else { return monthKey }
        switch style {
        case DateStyle.chinese.rawValue:
            return "\(parts[0])年\(Int(parts[1]) ?? 0)月"
        default:
            return monthKey
        }
    }
}
