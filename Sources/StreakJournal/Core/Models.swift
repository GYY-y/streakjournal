import Foundation

// MARK: - 数据模型

struct Cycle: Identifiable, Codable, Equatable {
    var id: Int64 = 0
    var startDate: String        // yyyy-MM-dd
    var endDate: String?         // nil 表示进行中
    var isActive: Bool = false
    var note: String?
    var createdAt: String = ""

    /// 周期天数（进行中则算到今天，含今天）
    var days: Int {
        let end = endDate ?? DateUtil.key(Date())
        guard let d = DateUtil.days(from: startDate, to: end) else { return 0 }
        return max(d + 1, 0)
    }
}

struct RelapseEvent: Identifiable, Codable, Equatable {
    var id: Int64 = 0
    var date: String             // yyyy-MM-dd，唯一
    var note: String?
    var createdAt: String = ""
}

struct DailyRecord: Identifiable, Codable, Equatable {
    var id: String { date }
    var date: String             // yyyy-MM-dd，主键
    var mood: String?            // 今日心态（单选）
    var emotions: [String] = []  // 今日情绪（多选）
    var state: String?           // 今日状态
    var perception: String?      // 今日变化与感知
    var freeText: String?        // 自由记录
    var contactedPorn: Bool?     // 是否接触色情内容（nil = 未填写）
    var targetBehavior: Bool?    // 是否发生目标行为
    var strongUrge: Bool?        // 是否出现明显冲动
    var behaviorNote: String?    // 行为备注
    var updatedAt: String = ""
}

// MARK: - 统计汇总

struct StatsSummary {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalCycles: Int = 0
    var totalPersistDays: Int = 0
    var relapseCount: Int = 0
    var recordCount: Int = 0
}

// MARK: - 导出 / 导入

struct ExportPayload: Codable {
    var version: Int
    var exportedAt: String
    var cycles: [Cycle]
    var relapses: [RelapseEvent]
    var records: [DailyRecord]
}
