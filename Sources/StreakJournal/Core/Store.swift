import Foundation
import SwiftUI

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var cycles: [Cycle] = []
    @Published private(set) var relapses: [RelapseEvent] = []
    @Published private(set) var records: [DailyRecord] = []   // 按日期倒序
    @Published var lastSavedAt: Date?
    @Published var lastMessage: String?

    var goalDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "goalDays")
            return v > 0 ? v : 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "goalDays")
            objectWillChange.send()
        }
    }

    var dateStyle: String {
        get { UserDefaults.standard.string(forKey: "dateStyle") ?? DateUtil.DateStyle.iso.rawValue }
        set {
            UserDefaults.standard.set(newValue, forKey: "dateStyle")
            objectWillChange.send()
        }
    }

    private let db = Database()
    private var bootstrapped = false
    private var backupTimer: Timer?

    // MARK: - 启动

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        do {
            try db.open()
            autoBackupIfNeeded()
            startBackupTimer()
            reload()
        } catch {
            lastMessage = LF("数据库打开失败：%@", error.localizedDescription)
        }
    }

    private func reload() {
        do {
            cycles = try db.fetchCycles()
            relapses = try db.fetchRelapses()
            records = try db.fetchRecords()
        } catch {
            lastMessage = LF("数据读取失败：%@", error.localizedDescription)
        }
    }

    // MARK: - 重置

    /// 重置全部业务数据：清空周期/破戒/每日记录与勋章，设置（目标天数、外观、语言）保留
    func resetAllData() {
        do {
            try db.resetAll()
            UserDefaults.standard.removeObject(forKey: "achievedBadges")
            UserDefaults.standard.removeObject(forKey: "lastPage")
            AppNav.shared.page = .home
            reload()
            lastMessage = L("已重置全部数据")
        } catch {
            reload()
            lastMessage = LF("重置失败：%@", error.localizedDescription)
        }
    }

    // MARK: - 派生数据

    var activeCycle: Cycle? { cycles.first { $0.isActive } }

    var todayKey: String { DateUtil.todayKey() }

    var hasRecordToday: Bool { records.contains { $0.date == todayKey } }

    var currentStreak: Int { activeCycle?.days ?? 0 }

    var longestStreak: Int {
        var longest = 0
        for c in cycles {
            let d = c.isActive ? currentStreak : c.days
            longest = max(longest, d)
        }
        return longest
    }

    var totalPersistDays: Int {
        var seen = Set<String>()
        for c in cycles {
            let end = c.endDate ?? todayKey
            guard let d = DateUtil.days(from: c.startDate, to: end) else { continue }
            for i in 0...max(d, 0) {
                seen.insert(DateUtil.addDays(c.startDate, i))
            }
        }
        return seen.count
    }

    var summary: StatsSummary {
        StatsSummary(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCycles: cycles.count,
            totalPersistDays: totalPersistDays,
            relapseCount: relapses.count,
            recordCount: records.count
        )
    }

    func relapseSet() -> Set<String> { Set(relapses.map { $0.date }) }

    func recordSet() -> Set<String> { Set(records.map { $0.date }) }

    func cycleStartSet() -> Set<String> { Set(cycles.map { $0.startDate }) }

    /// 某天是否属于某段周期（进行中周期最多算到今天）
    func cycleDays() -> Set<String> {
        var set = Set<String>()
        let today = todayKey
        for c in cycles {
            let end = c.isActive ? today : (c.endDate ?? c.startDate)
            guard let d = DateUtil.days(from: c.startDate, to: end) else { continue }
            for i in 0...max(d, 0) {
                set.insert(DateUtil.addDays(c.startDate, i))
            }
        }
        return set
    }

    func record(for date: String) -> DailyRecord? {
        records.first { $0.date == date }
    }

    // MARK: - 周期操作

    func startFirstCycle(on date: String? = nil) {
        let start = date ?? todayKey
        do {
            _ = try db.insertCycle(start: start, isActive: true, note: nil)
            reload()
            lastMessage = LF("已开启新的坚持周期（%@）", DateUtil.display(start, style: dateStyle))
        } catch {
            lastMessage = LF("创建周期失败：%@", error.localizedDescription)
        }
    }

    /// 开启新的周期。
    /// - relapseMarked: 是否将 relapseDate 标记为破戒日
    /// - relapseDate: 破戒日期（通常为今天）
    /// - newStart: 新周期开始日期
    func startNewCycle(relapseMarked: Bool, relapseDate: String, relapseNote: String?, newStart: String) {
        do {
            try db.transaction {
                if let active = activeCycle {
                    // 旧周期结束于破戒日前一天（若标记破戒）或新周期开始日前一天
                    let endBase = relapseMarked ? relapseDate : newStart
                    let endDate = DateUtil.addDays(endBase, -1)
                    if let d = DateUtil.days(from: active.startDate, to: endDate), d >= 0 {
                        try db.endCycle(id: active.id, endDate: endDate, active: false)
                    } else {
                        // 新开始日期不晚于旧周期起点时，直接结束旧周期于其开始日前一天
                        try db.endCycle(id: active.id, endDate: DateUtil.addDays(active.startDate, -1), active: false)
                    }
                }
                if relapseMarked {
                    try db.insertRelapse(date: relapseDate, note: relapseNote)
                }
                _ = try db.insertCycle(start: newStart, isActive: true, note: nil)
            }
            reload()
            let suffix = relapseMarked ? L("，已记录破戒事件") : ""
            lastMessage = LF("已开启新的坚持周期（%@）", DateUtil.display(newStart, style: dateStyle)) + suffix
        } catch {
            reload()
            lastMessage = LF("开启新周期失败：%@", error.localizedDescription)
        }
    }

    /// 补录破戒：破戒日独立保留，前一段周期结束于破戒日前一天；
    /// 若破戒日早于今天，自动从破戒日次日重新开始计算。
    func markBackdatedRelapse(date: String, note: String?) {
        let today = todayKey
        guard let d = DateUtil.days(from: date, to: today), d >= 0 else {
            lastMessage = L("破戒日期不能晚于今天")
            return
        }
        do {
            try db.transaction {
                guard let active = activeCycle else {
                    try db.insertRelapse(date: date, note: note)
                    return
                }
                if let dd = DateUtil.days(from: active.startDate, to: date), dd >= 0 {
                    try db.endCycle(id: active.id, endDate: DateUtil.addDays(date, -1), active: false)
                    try db.insertRelapse(date: date, note: note)
                    if d > 0 {
                        _ = try db.insertCycle(start: DateUtil.addDays(date, 1), isActive: true, note: nil)
                    }
                } else {
                    // 破戒日早于当前周期开始之前，仅记录事件
                    try db.insertRelapse(date: date, note: note)
                }
            }
            reload()
            lastMessage = LF("已补录破戒事件（%@）", DateUtil.display(date, style: dateStyle))
        } catch {
            reload()
            lastMessage = LF("补录失败：%@", error.localizedDescription)
        }
    }

    func updateCycle(_ cycle: Cycle) {
        do {
            try db.updateCycle(id: cycle.id, start: cycle.startDate, end: cycle.endDate, active: cycle.isActive, note: cycle.note)
            reload()
        } catch {
            lastMessage = LF("周期修改失败：%@", error.localizedDescription)
        }
    }

    func deleteCycle(_ cycle: Cycle) {
        do {
            try db.deleteCycle(id: cycle.id)
            reload()
        } catch {
            lastMessage = LF("周期删除失败：%@", error.localizedDescription)
        }
    }

    func deleteRelapse(_ relapse: RelapseEvent) {
        do {
            try db.deleteRelapse(date: relapse.date)
            reload()
        } catch {
            lastMessage = LF("删除破戒记录失败：%@", error.localizedDescription)
        }
    }

    // MARK: - 每日记录

    func saveRecord(_ record: DailyRecord) {
        do {
            try db.upsertRecord(record)
            reload()
            lastSavedAt = Date()
        } catch {
            lastMessage = LF("保存失败：%@", error.localizedDescription)
        }
    }

    func deleteRecord(date: String) {
        do {
            try db.deleteRecord(date: date)
            reload()
        } catch {
            lastMessage = LF("删除记录失败：%@", error.localizedDescription)
        }
    }

    // MARK: - 备份（系统自动，每 12 小时一次，无手动入口）

    private static let backupInterval: TimeInterval = 12 * 60 * 60   // 12 小时

    /// 每 30 分钟检查一次：距上次备份超过 12 小时就自动备份。
    /// 兼顾"应用一直开着"和"每天短时间打开"两种情况——启动时也会检查。
    private func startBackupTimer() {
        guard backupTimer == nil else { return }
        backupTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.autoBackupIfNeeded() }
        }
    }

    private func autoBackupIfNeeded() {
        let files = Self.backupFiles()
        if let last = files.first,
           let attr = try? FileManager.default.attributesOfItem(atPath: last.path),
           let modified = attr[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < Self.backupInterval {
            return
        }
        let name = "backup-\(Date().timeIntervalSince1970).db"
        let url = Database.backupsDirectory.appendingPathComponent(name)
        try? db.backup(to: url)
        pruneBackups(keep: 10)
    }

    static func backupFiles() -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: Database.backupsDirectory, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension == "db" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func pruneBackups(keep: Int) {
        let files = Self.backupFiles()
        guard files.count > keep else { return }
        for url in files.suffix(files.count - keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 导出 / 导入

    func exportData(to url: URL) throws {
        let payload = try db.exportAll()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    func importData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ExportPayload.self, from: data)
        try db.replaceAll(with: payload)
        reload()
    }
}
