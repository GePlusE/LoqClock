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
    var timezoneIdentifier: String
    var targetWorkDurationMinutes: Int
    var plannedBreakDurationMinutes: Int
    var additionalBreaks: [WorkBreak]
    var note: String?
    var sessions: [WorkSession]
    var isExplicitEmptyDay: Bool
    var createdAt: Date
    var updatedAt: Date

    var startTime: Date? {
        get { sessions.sorted { $0.startTimestamp < $1.startTimestamp }.first?.startTimestamp }
        set {
            setSingleSession(startTime: newValue, endTime: endTime)
        }
    }

    var endTime: Date? {
        get {
            guard sessions.count == 1 else {
                return sessions.sorted { $0.startTimestamp < $1.startTimestamp }.last?.endTimestamp
            }
            return sessions.first?.endTimestamp
        }
        set {
            setSingleSession(startTime: startTime, endTime: newValue)
        }
    }

    var lunchDurationMinutes: Int {
        get { plannedBreakDurationMinutes }
        set { plannedBreakDurationMinutes = newValue }
    }

    var notes: String? {
        get { note }
        set { note = WorkDayNote.sanitized(newValue) }
    }

    init(
        id: UUID = UUID(),
        date: LocalDay,
        startTime: Date? = nil,
        endTime: Date? = nil,
        timezoneIdentifier: String = TimeZone.current.identifier,
        targetWorkDurationMinutes: Int,
        lunchDurationMinutes: Int,
        additionalBreaks: [WorkBreak] = [],
        notes: String? = nil,
        sessions: [WorkSession]? = nil,
        isExplicitEmptyDay: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.timezoneIdentifier = timezoneIdentifier
        self.targetWorkDurationMinutes = targetWorkDurationMinutes
        self.plannedBreakDurationMinutes = lunchDurationMinutes
        self.additionalBreaks = additionalBreaks
        self.note = WorkDayNote.sanitized(notes)
        if let sessions {
            self.sessions = sessions.sorted { $0.startTimestamp < $1.startTimestamp }
        } else if let startTime {
            self.sessions = [
                WorkSession(
                    assignedWorkDayDate: date,
                    startTimestamp: startTime,
                    endTimestamp: endTime,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            ]
        } else {
            self.sessions = []
        }
        self.isExplicitEmptyDay = isExplicitEmptyDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func touch(_ timestamp: Date = .now) {
        updatedAt = timestamp
    }

    var hasMeaningfulContent: Bool {
        !sessions.isEmpty ||
        !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
        isExplicitEmptyDay
    }

    var activeSession: WorkSession? {
        sessions.first(where: { $0.endTimestamp == nil })
    }

    mutating func startNewSession(at timestamp: Date, now: Date = .now) {
        sessions.append(
            WorkSession(
                assignedWorkDayDate: date,
                startTimestamp: timestamp,
                createdAt: now,
                updatedAt: now
            )
        )
        sessions.sort { $0.startTimestamp < $1.startTimestamp }
        touch(now)
    }

    mutating func stopActiveSession(at timestamp: Date, now: Date = .now) -> WorkSession? {
        guard let index = sessions.firstIndex(where: { $0.endTimestamp == nil }) else {
            return nil
        }

        sessions[index].endTimestamp = timestamp
        sessions[index].touch(now)
        touch(now)
        return sessions[index]
    }

    mutating func undoStop(sessionID: UUID, now: Date = .now) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        sessions[index].endTimestamp = nil
        sessions[index].touch(now)
        touch(now)
    }

    static func makePlaceholder(
        for date: LocalDay,
        settings: AppSettings,
        now: Date = .now
    ) -> WorkDayEntry {
        WorkDayEntry(
            date: date,
            timezoneIdentifier: TimeZone.current.identifier,
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
        case timezoneIdentifier
        case startTime
        case endTime
        case targetWorkDurationMinutes
        case plannedBreakDurationMinutes
        case lunchDurationMinutes
        case additionalBreaks
        case additionalBreakDurationMinutes
        case notes
        case note
        case sessions
        case isExplicitEmptyDay
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(LocalDay.self, forKey: .date)
        timezoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timezoneIdentifier) ?? TimeZone.current.identifier
        let legacyStartTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        let legacyEndTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        targetWorkDurationMinutes = try container.decode(Int.self, forKey: .targetWorkDurationMinutes)
        plannedBreakDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .plannedBreakDurationMinutes)
            ?? container.decode(Int.self, forKey: .lunchDurationMinutes)
        if let breaks = try container.decodeIfPresent([WorkBreak].self, forKey: .additionalBreaks) {
            additionalBreaks = breaks
        } else {
            let legacyBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .additionalBreakDurationMinutes) ?? 0
            additionalBreaks = legacyBreakMinutes > 0 ? [WorkBreak(name: "Extra Break", durationMinutes: legacyBreakMinutes)] : []
        }
        note = WorkDayNote.sanitized(
            try container.decodeIfPresent(String.self, forKey: .note)
                ?? container.decodeIfPresent(String.self, forKey: .notes)
        )
        if let decodedSessions = try container.decodeIfPresent([WorkSession].self, forKey: .sessions) {
            sessions = decodedSessions.sorted { $0.startTimestamp < $1.startTimestamp }
        } else if let legacyStartTime {
            sessions = [
                WorkSession(
                    assignedWorkDayDate: date,
                    startTimestamp: legacyStartTime,
                    endTimestamp: legacyEndTime
                )
            ]
        } else {
            sessions = []
        }
        isExplicitEmptyDay = try container.decodeIfPresent(Bool.self, forKey: .isExplicitEmptyDay) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(timezoneIdentifier, forKey: .timezoneIdentifier)
        try container.encode(targetWorkDurationMinutes, forKey: .targetWorkDurationMinutes)
        try container.encode(plannedBreakDurationMinutes, forKey: .plannedBreakDurationMinutes)
        try container.encode(additionalBreaks, forKey: .additionalBreaks)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(sessions.sorted { $0.startTimestamp < $1.startTimestamp }, forKey: .sessions)
        try container.encode(isExplicitEmptyDay, forKey: .isExplicitEmptyDay)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private mutating func setSingleSession(startTime: Date?, endTime: Date?) {
        guard let startTime else {
            sessions = []
            return
        }

        let existing = sessions.first
        sessions = [
            WorkSession(
                id: existing?.id ?? UUID(),
                assignedWorkDayDate: date,
                startTimestamp: startTime,
                endTimestamp: endTime,
                createdAt: existing?.createdAt ?? createdAt,
                updatedAt: updatedAt
            )
        ]
    }
}
