import Foundation
import GRDB

final class EventStore {

    static let shared = EventStore()
    private var dbQueue: DatabaseQueue!

    private var cachedMonthSummary: MonthSummary?
    private var cachedMonthKey: String?

    private init() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clutch/events.db")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbQueue = try? DatabaseQueue(path: url.path)
        if let queue = dbQueue {
            try? Migrations.migrator.migrate(queue)
        }
    }

    func save(_ event: ClutchEvent) {
        try? dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO clutch_events (id, timestamp, device_name, volume, app_name, mode, risk_score)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id.uuidString,
                    event.timestamp,
                    event.deviceName,
                    event.volumeAtSave,
                    event.frontmostApp,
                    event.mode.rawValue,
                    event.riskScore
                ]
            )
        }

        invalidateMonthSummaryCache()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clutchEventSaved, object: nil)
        }
    }

    func recent(limit: Int = 50) -> [ClutchEvent] {
        var results: [ClutchEvent] = []
        try? dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM clutch_events ORDER BY timestamp DESC LIMIT ?",
                arguments: [limit]
            )
            results = rows.compactMap { Self.event(from: $0) }
        }
        return results
    }

    func totalEventCount() -> Int {
        var count = 0
        try? dbQueue.read { db in
            count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clutch_events") ?? 0
        }
        return count
    }

    /// Late-night saves between midnight and 5am (badge conditions).
    func lateNightBadgeCount() -> Int {
        var count = 0
        try? dbQueue.read { db in
            count = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM clutch_events
                WHERE CAST(strftime('%H', timestamp) AS INTEGER) >= 0
                  AND CAST(strftime('%H', timestamp) AS INTEGER) < 5
                """) ?? 0
        }
        return count
    }

    func currentStreakDays() -> Int {
        var streak = 0
        try? dbQueue.read { db in
            if let lastEventTime = try Date.fetchOne(db, sql: "SELECT MAX(timestamp) FROM clutch_events") {
                streak = Calendar.current.dateComponents([.day], from: lastEventTime, to: Date()).day ?? 0
            } else {
                streak = 30
            }
        }
        return streak
    }

    func thisMonthSummary() -> MonthSummary {
        let key = currentMonthKey()
        if cachedMonthKey == key, let cached = cachedMonthSummary {
            return cached
        }

        let summary = computeMonthSummary()
        cachedMonthSummary = summary
        cachedMonthKey = key
        return summary
    }

    func invalidateMonthSummaryCache() {
        cachedMonthSummary = nil
        cachedMonthKey = nil
    }

    private func currentMonthKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private func computeMonthSummary() -> MonthSummary {
        var totalSaves = 0
        var highestRisk = 0
        var lateNightSaves = 0

        try? dbQueue.read { db in
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

            totalSaves = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM clutch_events WHERE timestamp >= ?",
                arguments: [startOfMonth]
            ) ?? 0

            highestRisk = try Int.fetchOne(
                db,
                sql: "SELECT MAX(risk_score) FROM clutch_events WHERE timestamp >= ?",
                arguments: [startOfMonth]
            ) ?? 0

            lateNightSaves = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM clutch_events
                WHERE timestamp >= ?
                  AND (
                    CAST(strftime('%H', timestamp) AS INTEGER) >= 23
                    OR CAST(strftime('%H', timestamp) AS INTEGER) < 5
                  )
                """, arguments: [startOfMonth]) ?? 0
        }

        return MonthSummary(
            totalSaves: totalSaves,
            highestRisk: highestRisk,
            lateNightSaves: lateNightSaves,
            streakDays: currentStreakDays()
        )
    }

    func highestRiskRecentEvent(limit: Int = 100) -> ClutchEvent? {
        var result: ClutchEvent?
        try? dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT * FROM clutch_events
                WHERE id IN (
                    SELECT id FROM clutch_events ORDER BY timestamp DESC LIMIT ?
                )
                ORDER BY risk_score DESC
                LIMIT 1
                """, arguments: [limit])
            if let row { result = Self.event(from: row) }
        }
        return result
    }

    func mostSavedFromApp(limit: Int = 100) -> String {
        var appName = "Unknown"
        try? dbQueue.read { db in
            if let row = try Row.fetchOne(db, sql: """
                SELECT app_name, COUNT(*) AS cnt FROM clutch_events
                WHERE id IN (
                    SELECT id FROM clutch_events ORDER BY timestamp DESC LIMIT ?
                )
                GROUP BY app_name
                ORDER BY cnt DESC
                LIMIT 1
                """, arguments: [limit]),
               let name = row["app_name"] as? String {
                appName = name
            }
        }
        return appName
    }

    func buildWrappedStats() -> WrappedStats {
        let summary = thisMonthSummary()
        let earnedBadges = BadgeEngine.shared.earnedIDs
        let badges = Badge.all.filter { earnedBadges.contains($0.id) }

        return WrappedStats(
            month: "This Month",
            totalSaves: summary.totalSaves,
            highestRiskSave: highestRiskRecentEvent(),
            mostSavedFrom: mostSavedFromApp(),
            lateNightSaves: summary.lateNightSaves,
            bestStreak: summary.streakDays,
            badgesEarned: badges,
            headline: "you survived."
        )
    }

    func events(since date: Date) -> [ClutchEvent] {
        var results: [ClutchEvent] = []
        try? dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM clutch_events WHERE timestamp >= ? ORDER BY timestamp DESC",
                arguments: [date]
            )
            results = rows.compactMap { Self.event(from: $0) }
        }
        return results
    }

    func clearAll() {
        try? dbQueue.write { db in
            try db.execute(sql: "DELETE FROM clutch_events")
        }
        invalidateMonthSummaryCache()
    }

    private static func event(from row: Row) -> ClutchEvent? {
        guard let idString = row["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = row["timestamp"] as? Date,
              let deviceName = row["device_name"] as? String,
              let volume = row["volume"] as? Double,
              let appName = row["app_name"] as? String,
              let modeString = row["mode"] as? String,
              let mode = Mode(rawValue: modeString),
              let riskScore = row["risk_score"] as? Int else {
            return nil
        }

        return ClutchEvent(
            id: id,
            timestamp: timestamp,
            deviceName: deviceName,
            volumeAtSave: Float(volume),
            frontmostApp: appName,
            mode: mode,
            riskScore: riskScore
        )
    }
}

struct MonthSummary {
    let totalSaves:    Int
    let highestRisk:   Int
    let lateNightSaves: Int
    let streakDays:    Int
}
