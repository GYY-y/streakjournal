import Foundation
import SQLite3

enum DatabaseError: Error, LocalizedError {
    case sqlite(String)
    case notOpen
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .sqlite(let msg): return "数据库错误：\(msg)"
        case .notOpen: return "数据库未打开"
        case .invalidPayload(let msg): return "导入数据格式无效：\(msg)"
        }
    }
}

final class Database {
    private var db: OpaquePointer?
    private var isOpen = false

    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - 路径

    static var dataDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StreakJournal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var dbFileURL: URL { dataDirectory.appendingPathComponent("streakjournal.db") }

    static var backupsDirectory: URL {
        let dir = dataDirectory.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 打开 / 关闭

    func open() throws {
        guard !isOpen else { return }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(Database.dbFileURL.path, &handle, flags, nil) == SQLITE_OK, handle != nil else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
            sqlite3_close(handle)
            throw DatabaseError.sqlite(msg)
        }
        db = handle
        isOpen = true
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")
        try migrate()
    }

    func close() {
        guard isOpen else { return }
        try? exec("PRAGMA wal_checkpoint(TRUNCATE);")
        sqlite3_close(db)
        db = nil
        isOpen = false
    }

    deinit { close() }

    // MARK: - 建表

    private func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS cycles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_date TEXT NOT NULL,
            end_date TEXT,
            is_active INTEGER NOT NULL DEFAULT 0,
            note TEXT,
            created_at TEXT NOT NULL
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS relapses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            note TEXT,
            created_at TEXT NOT NULL
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS daily_records (
            date TEXT PRIMARY KEY,
            mood TEXT,
            emotions TEXT NOT NULL DEFAULT '[]',
            state TEXT,
            perception TEXT,
            free_text TEXT,
            contacted_porn INTEGER,
            target_behavior INTEGER,
            strong_urge INTEGER,
            behavior_note TEXT,
            updated_at TEXT NOT NULL
        );
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_cycles_start ON cycles(start_date);")
    }

    // MARK: - 基础工具

    private func exec(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errmsg) == SQLITE_OK else {
            let msg = errmsg.map { String(cString: $0) } ?? "未知错误"
            sqlite3_free(errmsg)
            throw DatabaseError.sqlite(msg)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func bindText(_ stmt: OpaquePointer, _ idx: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, idx, value, -1, Database.SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func bindInt(_ stmt: OpaquePointer, _ idx: Int32, _ value: Int) {
        sqlite3_bind_int64(stmt, idx, Int64(value))
    }

    private func bindNullableInt(_ stmt: OpaquePointer, _ idx: Int32, _ value: Bool?) {
        if let value {
            sqlite3_bind_int(stmt, idx, value ? 1 : 0)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func text(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(stmt, col))
    }

    private func optionalInt(_ stmt: OpaquePointer, _ col: Int32) -> Int? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(stmt, col))
    }

    private func optionalBool(_ stmt: OpaquePointer, _ col: Int32) -> Bool? {
        optionalInt(stmt, col).map { $0 != 0 }
    }

    private func lastRowID() -> Int64 { sqlite3_last_insert_rowid(db) }

    /// 在事务中执行一批操作
    func transaction(_ body: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try body()
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    // MARK: - 周期

    func fetchCycles() throws -> [Cycle] {
        let stmt = try prepare("SELECT id, start_date, end_date, is_active, note, created_at FROM cycles ORDER BY start_date DESC, id DESC;")
        defer { sqlite3_finalize(stmt) }
        var result: [Cycle] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(Cycle(
                id: sqlite3_column_int64(stmt, 0),
                startDate: text(stmt, 1) ?? "",
                endDate: text(stmt, 2),
                isActive: (sqlite3_column_int64(stmt, 3) != 0),
                note: text(stmt, 4),
                createdAt: text(stmt, 5) ?? ""
            ))
        }
        return result
    }

    @discardableResult
    func insertCycle(start: String, isActive: Bool, note: String?) throws -> Int64 {
        let stmt = try prepare("INSERT INTO cycles (start_date, end_date, is_active, note, created_at) VALUES (?, ?, ?, ?, ?);")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, start)
        sqlite3_bind_null(stmt, 2)
        bindInt(stmt, 3, isActive ? 1 : 0)
        bindText(stmt, 4, note)
        bindText(stmt, 5, DateUtil.now())
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return lastRowID()
    }

    func endCycle(id: Int64, endDate: String, active: Bool) throws {
        let stmt = try prepare("UPDATE cycles SET end_date = ?, is_active = ? WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, endDate)
        bindInt(stmt, 2, active ? 1 : 0)
        sqlite3_bind_int64(stmt, 3, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    func updateCycle(id: Int64, start: String, end: String?, active: Bool, note: String?) throws {
        let stmt = try prepare("UPDATE cycles SET start_date = ?, end_date = ?, is_active = ?, note = ? WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, start)
        bindText(stmt, 2, end)
        bindInt(stmt, 3, active ? 1 : 0)
        bindText(stmt, 4, note)
        sqlite3_bind_int64(stmt, 5, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteCycle(id: Int64) throws {
        let stmt = try prepare("DELETE FROM cycles WHERE id = ?;")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - 破戒事件

    func fetchRelapses() throws -> [RelapseEvent] {
        let stmt = try prepare("SELECT id, date, note, created_at FROM relapses ORDER BY date DESC;")
        defer { sqlite3_finalize(stmt) }
        var result: [RelapseEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(RelapseEvent(
                id: sqlite3_column_int64(stmt, 0),
                date: text(stmt, 1) ?? "",
                note: text(stmt, 2),
                createdAt: text(stmt, 3) ?? ""
            ))
        }
        return result
    }

    func insertRelapse(date: String, note: String?) throws {
        let stmt = try prepare("INSERT OR REPLACE INTO relapses (date, note, created_at) VALUES (?, ?, ?);")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, date)
        bindText(stmt, 2, note)
        bindText(stmt, 3, DateUtil.now())
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteRelapse(date: String) throws {
        let stmt = try prepare("DELETE FROM relapses WHERE date = ?;")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, date)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - 每日记录

    private func record(from stmt: OpaquePointer) -> DailyRecord {
        let emotionsRaw = text(stmt, 2) ?? "[]"
        let emotions = (try? JSONDecoder().decode([String].self, from: Data(emotionsRaw.utf8))) ?? []
        return DailyRecord(
            date: text(stmt, 0) ?? "",
            mood: text(stmt, 1),
            emotions: emotions,
            state: text(stmt, 3),
            perception: text(stmt, 4),
            freeText: text(stmt, 5),
            contactedPorn: optionalBool(stmt, 6),
            targetBehavior: optionalBool(stmt, 7),
            strongUrge: optionalBool(stmt, 8),
            behaviorNote: text(stmt, 9),
            updatedAt: text(stmt, 10) ?? ""
        )
    }

    func fetchRecords() throws -> [DailyRecord] {
        let stmt = try prepare("SELECT date, mood, emotions, state, perception, free_text, contacted_porn, target_behavior, strong_urge, behavior_note, updated_at FROM daily_records ORDER BY date DESC;")
        defer { sqlite3_finalize(stmt) }
        var result: [DailyRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(record(from: stmt))
        }
        return result
    }

    func upsertRecord(_ r: DailyRecord) throws {
        let stmt = try prepare("""
        INSERT INTO daily_records (date, mood, emotions, state, perception, free_text, contacted_porn, target_behavior, strong_urge, behavior_note, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
            mood=excluded.mood, emotions=excluded.emotions, state=excluded.state,
            perception=excluded.perception, free_text=excluded.free_text,
            contacted_porn=excluded.contacted_porn, target_behavior=excluded.target_behavior,
            strong_urge=excluded.strong_urge, behavior_note=excluded.behavior_note,
            updated_at=excluded.updated_at;
        """)
        defer { sqlite3_finalize(stmt) }
        let emotionsJSON = String(data: (try? JSONEncoder().encode(r.emotions)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        bindText(stmt, 1, r.date)
        bindText(stmt, 2, r.mood)
        bindText(stmt, 3, emotionsJSON)
        bindText(stmt, 4, r.state)
        bindText(stmt, 5, r.perception)
        bindText(stmt, 6, r.freeText)
        bindNullableInt(stmt, 7, r.contactedPorn)
        bindNullableInt(stmt, 8, r.targetBehavior)
        bindNullableInt(stmt, 9, r.strongUrge)
        bindText(stmt, 10, r.behaviorNote)
        bindText(stmt, 11, DateUtil.now())
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    func deleteRecord(date: String) throws {
        let stmt = try prepare("DELETE FROM daily_records WHERE date = ?;")
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, date)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - 导出 / 导入

    func exportAll() throws -> ExportPayload {
        ExportPayload(
            version: 1,
            exportedAt: DateUtil.now(),
            cycles: try fetchCycles(),
            relapses: try fetchRelapses(),
            records: try fetchRecords()
        )
    }

    func replaceAll(with payload: ExportPayload) throws {
        guard payload.version >= 1 else {
            throw DatabaseError.invalidPayload("缺少版本信息")
        }
        try transaction {
            try exec("DELETE FROM daily_records;")
            try exec("DELETE FROM relapses;")
            try exec("DELETE FROM cycles;")
            for c in payload.cycles {
                try updateOrInsertCycle(c)
            }
            for r in payload.relapses {
                try insertRelapse(date: r.date, note: r.note)
            }
            for r in payload.records {
                try upsertRecord(r)
            }
        }
    }

    private func updateOrInsertCycle(_ c: Cycle) throws {
        let stmt = try prepare("INSERT INTO cycles (id, start_date, end_date, is_active, note, created_at) VALUES (?, ?, ?, ?, ?, ?);")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, c.id)
        bindText(stmt, 2, c.startDate)
        bindText(stmt, 3, c.endDate)
        bindInt(stmt, 4, c.isActive ? 1 : 0)
        bindText(stmt, 5, c.note)
        bindText(stmt, 6, c.createdAt.isEmpty ? DateUtil.now() : c.createdAt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - 备份 / 恢复

    func backup(to url: URL) throws {
        try exec("PRAGMA wal_checkpoint(TRUNCATE);")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.copyItem(at: Database.dbFileURL, to: url)
    }
}
