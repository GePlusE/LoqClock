import Foundation

struct WorkDayEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var date: LocalDay
    var startTime: Date?
    var endTime: Date?
    var targetWorkDurationMinutes: Int
    var lunchDurationMinutes: Int
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: LocalDay,
        startTime: Date? = nil,
        endTime: Date? = nil,
        targetWorkDurationMinutes: Int,
        lunchDurationMinutes: Int,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.targetWorkDurationMinutes = targetWorkDurationMinutes
        self.lunchDurationMinutes = lunchDurationMinutes
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func touch(_ timestamp: Date = .now) {
        updatedAt = timestamp
    }

    static func makePlaceholder(
        for date: LocalDay,
        settings: AppSettings,
        now: Date = .now
    ) -> WorkDayEntry {
        WorkDayEntry(
            date: date,
            targetWorkDurationMinutes: settings.defaultTargetWorkDurationMinutes,
            lunchDurationMinutes: settings.defaultLunchDurationMinutes,
            createdAt: now,
            updatedAt: now
        )
    }
}
