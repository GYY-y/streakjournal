import Foundation

/// 勋章定义：参考徽章墙设计（连续徽章 + 累计徽章两组）
struct BadgeDef: Identifiable {
    enum Kind { case streak, cumulative }

    let id: String
    let name: String
    let emoji: String
    let threshold: Int
    let kind: Kind

    /// 显示名（随语言切换）
    var localizedName: String { L10n.t(name) }

    /// 显示条件（随语言切换）
    var localizedRequirement: String {
        switch kind {
        case .streak: return L10n.f("连续达成 %@ 天", "\(threshold)")
        case .cumulative: return L10n.f("累计打卡 %@ 次", "\(threshold)")
        }
    }
}

enum Badges {
    /// 连续徽章：按历史最长连续天数解锁
    static let streak: [BadgeDef] = [
        .init(id: "streak_3", name: "迈出第一步", emoji: "👣", threshold: 3, kind: .streak),
        .init(id: "streak_7", name: "初心者", emoji: "🌱", threshold: 7, kind: .streak),
        .init(id: "streak_14", name: "习惯养成", emoji: "🌿", threshold: 14, kind: .streak),
        .init(id: "streak_21", name: "三周达人", emoji: "🧠", threshold: 21, kind: .streak),
        .init(id: "streak_30", name: "健康卫士", emoji: "🛡️", threshold: 30, kind: .streak),
        .init(id: "streak_50", name: "半百之约", emoji: "⭐", threshold: 50, kind: .streak),
        .init(id: "streak_60", name: "钢铁意志", emoji: "💪", threshold: 60, kind: .streak),
        .init(id: "streak_90", name: "季度王者", emoji: "👑", threshold: 90, kind: .streak),
        .init(id: "streak_100", name: "传奇坚持", emoji: "🏆", threshold: 100, kind: .streak),
        .init(id: "streak_180", name: "半年之星", emoji: "💎", threshold: 180, kind: .streak),
        .init(id: "streak_365", name: "年度传说", emoji: "🐉", threshold: 365, kind: .streak),
    ]

    /// 累计徽章：按累计打卡（每日记录）次数解锁
    static let cumulative: [BadgeDef] = [
        .init(id: "cum_10", name: "初始积累", emoji: "📌", threshold: 10, kind: .cumulative),
        .init(id: "cum_20", name: "渐入佳境", emoji: "✌️", threshold: 20, kind: .cumulative),
        .init(id: "cum_50", name: "半百积累", emoji: "🎖️", threshold: 50, kind: .cumulative),
        .init(id: "cum_100", name: "百里征程", emoji: "💯", threshold: 100, kind: .cumulative),
        .init(id: "cum_200", name: "双百突破", emoji: "🎯", threshold: 200, kind: .cumulative),
        .init(id: "cum_500", name: "五百征途", emoji: "🚀", threshold: 500, kind: .cumulative),
        .init(id: "cum_1000", name: "千次大师", emoji: "🌟", threshold: 1000, kind: .cumulative),
        .init(id: "cum_2000", name: "两千巅峰", emoji: "🔥", threshold: 2000, kind: .cumulative),
        .init(id: "cum_5000", name: "五千传奇", emoji: "🏅", threshold: 5000, kind: .cumulative),
    ]

    static let all: [BadgeDef] = streak + cumulative

    /// 当前进度值：连续天数 / 累计打卡次数
    static func currentValue(for kind: BadgeDef.Kind, longestStreak: Int, recordCount: Int) -> Int {
        switch kind {
        case .streak: return longestStreak
        case .cumulative: return recordCount
        }
    }
}
