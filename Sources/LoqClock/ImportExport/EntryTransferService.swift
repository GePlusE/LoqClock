import Foundation

enum EntryTransferFormat: String, CaseIterable, Sendable {
    case json
    case csv

    var fileExtension: String {
        rawValue
    }
}

enum ImportConflictStrategy: Sendable {
    case replaceExisting
    case skipExisting
}

struct ImportedEntryPayload: Sendable {
    var settings: AppSettings?
    var entries: [WorkDayEntry]
}

struct ImportApplicationSummary: Sendable {
    var importedCount: Int
    var replacedCount: Int
    var skippedCount: Int
    var settingsUpdated: Bool
}

enum EntryTransferError: LocalizedError {
    case invalidJSON
    case invalidCSVHeader
    case invalidCSVRow(Int)
    case invalidDate(String)
    case duplicateDatesInImport([String])
    case invalidBreakEncoding
    case invalidBreakDuration
    case noFileSelected

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The JSON file could not be parsed."
        case .invalidCSVHeader:
            return "The CSV file header is invalid."
        case .invalidCSVRow(let row):
            return "The CSV file contains an invalid row at line \(row)."
        case .invalidDate(let value):
            return "The file contains an invalid date value: \(value)."
        case .duplicateDatesInImport(let dates):
            return "The import file contains duplicate dates: \(dates.joined(separator: ", "))."
        case .invalidBreakEncoding:
            return "The file contains invalid additional break data."
        case .invalidBreakDuration:
            return "The file contains an invalid break duration."
        case .noFileSelected:
            return "No file was selected."
        }
    }
}

struct EntryTransferService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func exportData(state: AppState, format: EntryTransferFormat) throws -> Data {
        switch format {
        case .json:
            return try encoder.encode(state)
        case .csv:
            return Data(exportCSV(entries: state.entries).utf8)
        }
    }

    func importData(_ data: Data, format: EntryTransferFormat) throws -> ImportedEntryPayload {
        switch format {
        case .json:
            return try importJSON(data)
        case .csv:
            return try importCSV(data)
        }
    }

    private func importJSON(_ data: Data) throws -> ImportedEntryPayload {
        if let state = try? decoder.decode(AppState.self, from: data) {
            try validateUniqueDates(in: state.entries)
            return ImportedEntryPayload(settings: state.settings, entries: state.entries)
        }

        if let entries = try? decoder.decode([WorkDayEntry].self, from: data) {
            try validateUniqueDates(in: entries)
            return ImportedEntryPayload(settings: nil, entries: entries)
        }

        throw EntryTransferError.invalidJSON
    }

    private func importCSV(_ data: Data) throws -> ImportedEntryPayload {
        guard let content = String(data: data, encoding: .utf8) else {
            throw EntryTransferError.invalidCSVHeader
        }

        let rows = parseCSV(content)
        guard let header = rows.first else {
            throw EntryTransferError.invalidCSVHeader
        }

        if header == legacyCSVHeader {
            return try importLegacyCSV(rows)
        }

        guard header == csvHeader else {
            throw EntryTransferError.invalidCSVHeader
        }

        return try importSessionCSV(rows)
    }

    private func importSessionCSV(_ rows: [[String]]) throws -> ImportedEntryPayload {
        var builders: [LocalDay: CSVEntryBuilder] = [:]
        var orderedDays: [LocalDay] = []

        for (index, row) in rows.dropFirst().enumerated() {
            let row = normalizedCSVRow(row, expectedCount: csvHeader.count)

            if row.allSatisfy(\.isEmpty) {
                continue
            }

            guard row.count == csvHeader.count else {
                throw EntryTransferError.invalidCSVRow(index + 2)
            }

            let day = try localDay(row[0])
            let timezoneIdentifier = row[1].isEmpty ? TimeZone.current.identifier : row[1]

            guard let target = Int(row[2]),
                  let plannedBreak = Int(row[3]) else {
                throw EntryTransferError.invalidCSVRow(index + 2)
            }

            let note = WorkDayNote.sanitized(row[4])

            if var existingBuilder = builders[day] {
                guard existingBuilder.timezoneIdentifier == timezoneIdentifier,
                      existingBuilder.targetWorkDurationMinutes == target,
                      existingBuilder.plannedBreakDurationMinutes == plannedBreak,
                      existingBuilder.note == note else {
                    throw EntryTransferError.invalidCSVRow(index + 2)
                }

                if let session = try makeSession(from: row, day: day) {
                    existingBuilder.sessions.append(session)
                }

                builders[day] = existingBuilder
            } else {
                var builder = CSVEntryBuilder(
                    day: day,
                    timezoneIdentifier: timezoneIdentifier,
                    targetWorkDurationMinutes: target,
                    plannedBreakDurationMinutes: plannedBreak,
                    note: note,
                    sessions: []
                )

                if let session = try makeSession(from: row, day: day) {
                    builder.sessions.append(session)
                }

                builders[day] = builder
                orderedDays.append(day)
            }
        }

        let entries = orderedDays.compactMap { builders[$0]?.makeEntry() }
        return ImportedEntryPayload(settings: nil, entries: entries)
    }

    private func importLegacyCSV(_ rows: [[String]]) throws -> ImportedEntryPayload {
        var entries: [WorkDayEntry] = []

        for (index, row) in rows.dropFirst().enumerated() {
            let row = normalizedCSVRow(row, expectedCount: legacyCSVHeader.count)

            if row.allSatisfy(\.isEmpty) {
                continue
            }

            guard row.count == legacyCSVHeader.count else {
                throw EntryTransferError.invalidCSVRow(index + 2)
            }

            guard let entry = try makeLegacyEntry(from: row) else {
                throw EntryTransferError.invalidCSVRow(index + 2)
            }

            entries.append(entry)
        }

        try validateUniqueDates(in: entries)
        return ImportedEntryPayload(settings: nil, entries: entries)
    }

    private func exportCSV(entries: [WorkDayEntry]) -> String {
        var rows = [csvHeader]

        for entry in entries {
            let sortedSessions = entry.sessions.sorted { $0.startTimestamp < $1.startTimestamp }

            if sortedSessions.isEmpty {
                rows.append([
                    entry.date.id,
                    entry.timezoneIdentifier,
                    "\(entry.targetWorkDurationMinutes)",
                    "\(entry.plannedBreakDurationMinutes)",
                    entry.notes ?? "",
                    "",
                    "",
                    ""
                ])
            } else {
                for session in sortedSessions {
                    rows.append([
                        entry.date.id,
                        entry.timezoneIdentifier,
                        "\(entry.targetWorkDurationMinutes)",
                        "\(entry.plannedBreakDurationMinutes)",
                        entry.notes ?? "",
                        session.id.uuidString,
                        iso8601String(session.startTimestamp),
                        iso8601String(session.endTimestamp)
                    ])
                }
            }
        }

        return rows.map(csvLine).joined(separator: "\n")
    }

    private func makeLegacyEntry(from row: [String]) throws -> WorkDayEntry? {
        let day = try localDay(row[0])

        guard let target = Int(row[3]),
              let lunch = Int(row[4]) else {
            return nil
        }

        return WorkDayEntry(
            date: day,
            startTime: try iso8601Date(row[1]),
            endTime: try iso8601Date(row[2]),
            targetWorkDurationMinutes: target,
            lunchDurationMinutes: lunch,
            additionalBreaks: try decodeBreaks(row[5]),
            notes: row[6].isEmpty ? nil : row[6]
        )
    }

    private func makeSession(from row: [String], day: LocalDay) throws -> WorkSession? {
        let sessionID = row[5]
        let startValue = row[6]
        let endValue = row[7]

        if sessionID.isEmpty && startValue.isEmpty && endValue.isEmpty {
            return nil
        }

        guard let start = try iso8601Date(startValue) else {
            throw EntryTransferError.invalidCSVRow(0)
        }

        return WorkSession(
            id: UUID(uuidString: sessionID) ?? UUID(),
            assignedWorkDayDate: day,
            startTimestamp: start,
            endTimestamp: try iso8601Date(endValue)
        )
    }

    private func localDay(_ value: String) throws -> LocalDay {
        let dateParts = value.split(separator: "-").map(String.init)
        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else {
            throw EntryTransferError.invalidDate(value)
        }

        return LocalDay(year: year, month: month, day: day)
    }

    private struct CSVEntryBuilder {
        var day: LocalDay
        var timezoneIdentifier: String
        var targetWorkDurationMinutes: Int
        var plannedBreakDurationMinutes: Int
        var note: String?
        var sessions: [WorkSession]

        func makeEntry() -> WorkDayEntry {
            WorkDayEntry(
                date: day,
                timezoneIdentifier: timezoneIdentifier,
                targetWorkDurationMinutes: targetWorkDurationMinutes,
                lunchDurationMinutes: plannedBreakDurationMinutes,
                additionalBreaks: [],
                notes: note,
                sessions: sessions.sorted { $0.startTimestamp < $1.startTimestamp }
            )
        }
    }

    private func validateUniqueDates(in entries: [WorkDayEntry]) throws {
        var seen = Set<String>()
        var duplicates = Set<String>()

        for entry in entries {
            let key = entry.date.id
            if !seen.insert(key).inserted {
                duplicates.insert(key)
            }
        }

        if !duplicates.isEmpty {
            throw EntryTransferError.duplicateDatesInImport(Array(duplicates).sorted())
        }
    }

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]

            if isInsideQuotes {
                if character == "\"" {
                    let nextIndex = content.index(after: index)
                    if nextIndex < content.endIndex, content[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isInsideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(character)
                }
            }

            index = content.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private func csvLine(_ fields: [String]) -> String {
        fields
            .map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            .joined(separator: ",")
    }

    private func normalizedCSVRow(_ row: [String], expectedCount: Int) -> [String] {
        let trimmed = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard trimmed.count < expectedCount else {
            return trimmed
        }

        return trimmed + Array(repeating: "", count: expectedCount - trimmed.count)
    }

    private func breaksJSONString(_ breaks: [WorkBreak]) -> String {
        let compactEncoder = JSONEncoder()
        compactEncoder.outputFormatting = [.sortedKeys]
        guard let data = try? compactEncoder.encode(breaks),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private func decodeBreaks(_ value: String) throws -> [WorkBreak] {
        if value.isEmpty {
            return []
        }

        guard let data = value.data(using: .utf8) else {
            throw EntryTransferError.invalidBreakEncoding
        }

        do {
            let breaks = try JSONDecoder().decode([WorkBreak].self, from: data)
            if breaks.contains(where: { $0.durationMinutes < 0 }) {
                throw EntryTransferError.invalidBreakDuration
            }
            return breaks
        } catch let error as EntryTransferError {
            throw error
        } catch {
            throw EntryTransferError.invalidBreakEncoding
        }
    }

    private func iso8601String(_ date: Date?) -> String {
        guard let date else { return "" }
        return ISO8601DateFormatter().string(from: date)
    }

    private func iso8601Date(_ value: String) throws -> Date? {
        guard !value.isEmpty else {
            return nil
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        throw EntryTransferError.invalidDate(value)
    }

    private var csvHeader: [String] {
        [
            "date",
            "timezone_identifier",
            "target_work_duration_minutes",
            "planned_break_duration_minutes",
            "note",
            "session_id",
            "session_start_timestamp",
            "session_end_timestamp"
        ]
    }

    private var legacyCSVHeader: [String] {
        [
            "date",
            "start_time",
            "end_time",
            "target_work_duration_minutes",
            "lunch_duration_minutes",
            "additional_breaks_json",
            "notes"
        ]
    }
}
