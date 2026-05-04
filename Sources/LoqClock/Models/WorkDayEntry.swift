import Foundation

struct WorkBreak: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var durationMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        durationMinutes: Int
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
    }
}

struct WorkDayEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var date: LocalDay
    var startTime: Date?
    var endTime: Date?
    var targetWorkDurationMinutes: Int
    var lunchDurationMinutes: Int
    var additionalBreaks: [WorkBreak]
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
        additionalBreaks: [WorkBreak] = [],
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
        self.additionalBreaks = additionalBreaks
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
            additionalBreaks: [],
            createdAt: now,
            updatedAt: now
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case startTime
        case endTime
        case targetWorkDurationMinutes
        case lunchDurationMinutes
        case additionalBreaks
        case additionalBreakDurationMinutes
        case notes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(LocalDay.self, forKey: .date)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        targetWorkDurationMinutes = try container.decode(Int.self, forKey: .targetWorkDurationMinutes)
        lunchDurationMinutes = try container.decode(Int.self, forKey: .lunchDurationMinutes)
        if let breaks = try container.decodeIfPresent([WorkBreak].self, forKey: .additionalBreaks) {
            additionalBreaks = breaks
        } else {
            let legacyBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .additionalBreakDurationMinutes) ?? 0
            additionalBreaks = legacyBreakMinutes > 0 ? [WorkBreak(name: "Extra Break", durationMinutes: legacyBreakMinutes)] : []
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(targetWorkDurationMinutes, forKey: .targetWorkDurationMinutes)
        try container.encode(lunchDurationMinutes, forKey: .lunchDurationMinutes)
        try container.encode(additionalBreaks, forKey: .additionalBreaks)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
