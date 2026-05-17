import AppKit
import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class LoqClockStore {
    private(set) var settings: AppSettings
    private(set) var entries: [WorkDayEntry]
    private(set) var launchAtLoginErrorMessage: String?
    private(set) var availableUpdate: AppReleaseInfo?
    private(set) var updateCheckErrorMessage: String?
    private(set) var updateCheckStatusMessage: String?
    private(set) var isCheckingForUpdates = false

    private let persistence: LoqClockPersistence
    let calendar: Calendar
    let calculator: WorkTimeCalculator
    let transferService: EntryTransferService
    let launchAtLoginService: LaunchAtLoginService
    let appUpdateService: AppUpdateService
    let backupService: LoqClockBackupService

    init(
        persistence: LoqClockPersistence = .live(),
        calendar: Calendar = .current,
        launchAtLoginService: LaunchAtLoginService = .live(),
        appUpdateService: AppUpdateService = .live(),
        backupService: LoqClockBackupService = .live()
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.calculator = WorkTimeCalculator(calendar: calendar)
        self.transferService = EntryTransferService()
        self.launchAtLoginService = launchAtLoginService
        self.appUpdateService = appUpdateService
        self.backupService = backupService

        let state = (try? persistence.load()) ?? AppState()
        var loadedSettings = state.settings
        loadedSettings.launchAtLoginEnabled = launchAtLoginService.currentState()
        self.settings = loadedSettings
        self.entries = state.entries.sorted { $0.date < $1.date }
    }

    var shouldShowLaunchAtLoginPrompt: Bool {
        !settings.launchAtLoginPromptHandled && !entries.isEmpty
    }

    var activeEntry: WorkDayEntry? {
        entries.first { entry in
            entry.activeSession != nil
        }
    }

    var hasActiveSession: Bool {
        activeEntry != nil
    }

    func entry(for day: LocalDay) -> WorkDayEntry? {
        entries.first(where: { $0.date == day })
    }

    @discardableResult
    func ensureEntry(for day: LocalDay, now: Date = .now) -> WorkDayEntry {
        if let existing = entry(for: day) {
            return existing
        }

        let entry = WorkDayEntry.makePlaceholder(for: day, settings: settings, now: now)
        createOrUpdateEntry(entry, now: now)
        return entry
    }

    func createOrUpdateEntry(_ entry: WorkDayEntry, now: Date = .now) {
        var entry = entry
        entry.note = WorkDayNote.sanitized(entry.note)
        entry.touch(now)

        if let index = entries.firstIndex(where: { $0.date == entry.date }) {
            entry = WorkDayEntry(
                id: entries[index].id,
                date: entry.date,
                timezoneIdentifier: entry.timezoneIdentifier,
                targetWorkDurationMinutes: entry.targetWorkDurationMinutes,
                lunchDurationMinutes: entry.lunchDurationMinutes,
                additionalBreaks: entry.additionalBreaks,
                notes: entry.notes,
                sessions: entry.sessions,
                isExplicitEmptyDay: entry.isExplicitEmptyDay,
                createdAt: entries[index].createdAt,
                updatedAt: now
            )
            entries[index] = entry
        } else {
            entries.append(entry)
        }

        entries.sort { $0.date < $1.date }
        save()
    }

    func upsertEntry(
        for day: LocalDay,
        now: Date = .now,
        mutate: (inout WorkDayEntry) -> Void
    ) {
        var entry = entry(for: day) ?? WorkDayEntry.makePlaceholder(for: day, settings: settings, now: now)
        mutate(&entry)
        createOrUpdateEntry(entry, now: now)
    }

    func deleteEntry(for day: LocalDay) {
        if entry(for: day) != nil {
            createRecoveryBackup(reason: "delete-\(day.id)")
        }

        entries.removeAll(where: { $0.date == day })
        save()
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        save()
    }

    func resetTrackingData(now: Date = .now) {
        createRecoveryBackup(reason: "reset-tracking-data", now: now)
        entries = []
        save()
    }

    func resetEverything(now: Date = .now) {
        createRecoveryBackup(reason: "reset-everything", now: now)
        settings = .default
        settings.launchAtLoginEnabled = launchAtLoginService.currentState()
        entries = []
        availableUpdate = nil
        updateCheckErrorMessage = nil
        updateCheckStatusMessage = nil
        save()
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        do {
            let actualEnabled = try launchAtLoginService.setEnabled(enabled)
            launchAtLoginErrorMessage = nil
            settings.launchAtLoginEnabled = actualEnabled
            save()
            return actualEnabled
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
            settings.launchAtLoginEnabled = launchAtLoginService.currentState()
            save()
            return settings.launchAtLoginEnabled
        }
    }

    func handleLaunchAtLoginPrompt(enable: Bool) {
        settings.launchAtLoginPromptHandled = true
        save()

        if enable {
            _ = setLaunchAtLoginEnabled(true)
        } else {
            launchAtLoginErrorMessage = nil
        }
    }

    var shouldOfferAutomaticUpdateCheck: Bool {
        settings.automaticallyCheckForUpdates
    }

    func shouldPerformAutomaticUpdateCheck(now: Date = .now) -> Bool {
        guard settings.automaticallyCheckForUpdates else {
            return false
        }

        guard let lastSuccessfulUpdateCheckAt = settings.lastSuccessfulUpdateCheckAt else {
            return true
        }

        return now.timeIntervalSince(lastSuccessfulUpdateCheckAt) >= 7 * 24 * 60 * 60
    }

    func performAutomaticUpdateCheckIfNeeded(now: Date = .now) async {
        guard shouldPerformAutomaticUpdateCheck(now: now) else {
            return
        }

        do {
            try await checkForUpdates(manual: false, now: now)
        } catch {
            updateCheckErrorMessage = nil
            updateCheckStatusMessage = nil
        }
    }

    func setAutomaticUpdateChecksEnabled(_ enabled: Bool) {
        settings.automaticallyCheckForUpdates = enabled
        save()
    }

    func checkForUpdates(manual: Bool, now: Date = .now) async throws {
        guard !isCheckingForUpdates else {
            return
        }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let release = try await appUpdateService.fetchLatestStableRelease()
            let isUpdateAvailable = try appUpdateService.isUpdateAvailable(comparedTo: release)
            settings.lastSuccessfulUpdateCheckAt = now
            availableUpdate = isUpdateAvailable ? release : nil
            updateCheckErrorMessage = nil
            updateCheckStatusMessage = manual && !isUpdateAvailable ? "LoqClock is up to date." : nil
            save()
        } catch AppUpdateError.noPublishedRelease {
            availableUpdate = nil
            updateCheckErrorMessage = nil
            updateCheckStatusMessage = manual ? AppUpdateError.noPublishedRelease.localizedDescription : nil
        } catch {
            if manual {
                updateCheckErrorMessage = error.localizedDescription
                updateCheckStatusMessage = nil
            } else {
                updateCheckErrorMessage = nil
                updateCheckStatusMessage = nil
            }
            throw error
        }
    }

    func openAvailableUpdateDownload() {
        guard let url = availableUpdate?.downloadURL ?? availableUpdate?.releasePageURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func dismissAvailableUpdate() {
        availableUpdate = nil
        updateCheckErrorMessage = nil
        updateCheckStatusMessage = nil
    }

    func startToday(now: Date = .now) {
        let today = LocalDay(date: now, calendar: calendar)
        let normalizedStart = TimeNormalizer.roundedDownToMinute(now)

        guard activeEntryIndex() == nil else {
            return
        }

        upsertEntry(for: today, now: now) { entry in
            entry.startNewSession(at: normalizedStart, now: now)
        }
    }

    @discardableResult
    func endToday(now: Date = .now) -> StoppedWorkSession? {
        let normalizedEnd = TimeNormalizer.roundedUpToMinuteIfNeeded(now)

        guard let index = activeEntryIndex() else {
            return nil
        }

        var entry = entries[index]
        guard let stoppedSession = entry.stopActiveSession(at: normalizedEnd, now: now) else {
            return nil
        }

        if calculator.sessionDurationMinutes(for: stoppedSession, now: now) < 1 {
            entry.sessions.removeAll { $0.id == stoppedSession.id }
            if entry.hasMeaningfulContent {
                createOrUpdateEntry(entry, now: now)
            } else {
                entries.remove(at: index)
                save()
            }
            return nil
        }

        if entry.hasMeaningfulContent {
            createOrUpdateEntry(entry, now: now)
        } else {
            entries.remove(at: index)
            save()
            return nil
        }

        return StoppedWorkSession(day: entry.date, sessionID: stoppedSession.id)
    }

    func clearTodayEndTime(now: Date = .now) {
        startToday(now: now)
    }

    func undoStop(_ stoppedSession: StoppedWorkSession, now: Date = .now) {
        guard activeEntryIndex() == nil,
              let index = entries.firstIndex(where: { $0.date == stoppedSession.day }) else {
            return
        }

        var entry = entries[index]
        entry.undoStop(sessionID: stoppedSession.sessionID, now: now)
        createOrUpdateEntry(entry, now: now)
    }

    func exportStateData(format: EntryTransferFormat) throws -> Data {
        try transferService.exportData(
            state: AppState(settings: settings, entries: entries),
            format: format
        )
    }

    func duplicateImportDates(for payload: ImportedEntryPayload) -> [LocalDay] {
        let existingDays = Set(entries.map(\.date))
        return payload.entries
            .map(\.date)
            .filter { existingDays.contains($0) }
            .sorted()
    }

    @discardableResult
    func applyImportedPayload(
        _ payload: ImportedEntryPayload,
        strategy: ImportConflictStrategy
    ) -> ImportApplicationSummary {
        createRecoveryBackup(reason: "before-import")

        var importedCount = 0
        var replacedCount = 0
        var skippedCount = 0

        for importedEntry in payload.entries {
            let alreadyExists = entry(for: importedEntry.date) != nil

            if alreadyExists {
                switch strategy {
                case .replaceExisting:
                    createOrUpdateEntry(importedEntry)
                    importedCount += 1
                    replacedCount += 1
                case .skipExisting:
                    skippedCount += 1
                }
            } else {
                createOrUpdateEntry(importedEntry)
                importedCount += 1
            }
        }

        let settingsUpdated: Bool
        if let importedSettings = payload.settings {
            updateSettings(importedSettings)
            settingsUpdated = true
        } else {
            settingsUpdated = false
        }

        return ImportApplicationSummary(
            importedCount: importedCount,
            replacedCount: replacedCount,
            skippedCount: skippedCount,
            settingsUpdated: settingsUpdated
        )
    }

    private func save() {
        let state = AppState(settings: settings, entries: entries)

        do {
            try persistence.save(state)
        } catch {
            assertionFailure("Failed to save LoqClock state: \(error)")
        }
    }

    private func createRecoveryBackup(reason: String, now: Date = .now) {
        do {
            _ = try backupService.createBackup(
                AppState(settings: settings, entries: entries),
                reason,
                now
            )
        } catch {
            assertionFailure("Failed to create LoqClock backup: \(error)")
        }
    }

    private func activeEntryIndex() -> Int? {
        entries.firstIndex { entry in
            entry.activeSession != nil
        }
    }
}

struct StoppedWorkSession: Equatable, Sendable {
    var day: LocalDay
    var sessionID: UUID
}

struct AppState: Codable, Equatable, Sendable {
    var settings: AppSettings
    var entries: [WorkDayEntry]

    init(
        settings: AppSettings = .default,
        entries: [WorkDayEntry] = []
    ) {
        self.settings = settings
        self.entries = entries
    }
}

struct LoqClockPersistence {
    let load: () throws -> AppState
    let save: (AppState) throws -> Void

    static func live(fileManager: FileManager = .default) -> LoqClockPersistence {
        let fileURL = databaseURL(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dateFormatter = ISO8601DateFormatter()

        let databaseQueue: DatabaseQueue

        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            databaseQueue = try DatabaseQueue(path: fileURL.path)
            try migrate(databaseQueue)
        } catch {
            assertionFailure("Failed to initialize LoqClock database: \(error)")
            return .memory()
        }

        return LoqClockPersistence(
            load: {
                try databaseQueue.read { db in
                    let settings = try loadSettings(db: db, decoder: decoder)
                    let entries = try loadEntries(db: db, dateFormatter: dateFormatter)
                    return AppState(settings: settings, entries: entries)
                }
            },
            save: { state in
                try databaseQueue.write { db in
                    try save(state: state, db: db, encoder: encoder, dateFormatter: dateFormatter)
                }
            }
        )
    }

    private static func databaseURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseURL
            .appending(path: "LoqClock", directoryHint: .isDirectory)
            .appending(path: "LoqClock.sqlite", directoryHint: .notDirectory)
    }

    private static func migrate(_ databaseQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("create_sdd_core_tables") { db in
            try db.create(table: "settings", ifNotExists: true) { table in
                table.column("key", .text).primaryKey()
                table.column("value", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(table: "work_days", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("work_day_date", .text).notNull().unique()
                table.column("timezone_identifier", .text).notNull()
                table.column("target_work_duration_minutes", .integer).notNull()
                table.column("planned_break_duration_minutes", .integer).notNull()
                table.column("note", .text)
                table.column("is_explicit_empty_day", .boolean).notNull().defaults(to: false)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }

            try db.create(table: "work_sessions", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("work_day_id", .text).notNull().references("work_days", onDelete: .cascade)
                table.column("assigned_work_day_date", .text).notNull()
                table.column("start_timestamp", .text).notNull()
                table.column("end_timestamp", .text)
                table.column("created_at", .text).notNull()
                table.column("updated_at", .text).notNull()
            }
        }

        try migrator.migrate(databaseQueue)
    }

    private static func loadSettings(db: Database, decoder: JSONDecoder) throws -> AppSettings {
        guard let row = try Row.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: ["app_settings"]),
              let json = row["value"] as String?,
              let data = json.data(using: .utf8) else {
            return .default
        }

        return try decoder.decode(AppSettings.self, from: data)
    }

    private static func loadEntries(db: Database, dateFormatter: ISO8601DateFormatter) throws -> [WorkDayEntry] {
        let dayRows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, work_day_date, timezone_identifier, target_work_duration_minutes,
                   planned_break_duration_minutes, note, is_explicit_empty_day, created_at, updated_at
            FROM work_days
            ORDER BY work_day_date
            """
        )

        return try dayRows.map { dayRow in
            let id = UUID(uuidString: dayRow["id"]) ?? UUID()
            let day = LocalDay(id: dayRow["work_day_date"])
            let sessionRows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, assigned_work_day_date, start_timestamp, end_timestamp, created_at, updated_at
                FROM work_sessions
                WHERE work_day_id = ?
                ORDER BY start_timestamp
                """,
                arguments: [dayRow["id"] as String]
            )
            let sessions = sessionRows.compactMap { row -> WorkSession? in
                guard let start = dateFormatter.date(from: row["start_timestamp"]) else {
                    return nil
                }

                return WorkSession(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    assignedWorkDayDate: LocalDay(id: row["assigned_work_day_date"]),
                    startTimestamp: start,
                    endTimestamp: (row["end_timestamp"] as String?).flatMap { dateFormatter.date(from: $0) },
                    createdAt: (row["created_at"] as String?).flatMap { dateFormatter.date(from: $0) } ?? start,
                    updatedAt: (row["updated_at"] as String?).flatMap { dateFormatter.date(from: $0) } ?? start
                )
            }

            return WorkDayEntry(
                id: id,
                date: day,
                timezoneIdentifier: dayRow["timezone_identifier"],
                targetWorkDurationMinutes: dayRow["target_work_duration_minutes"],
                lunchDurationMinutes: dayRow["planned_break_duration_minutes"],
                notes: dayRow["note"],
                sessions: sessions,
                isExplicitEmptyDay: dayRow["is_explicit_empty_day"],
                createdAt: (dayRow["created_at"] as String?).flatMap { dateFormatter.date(from: $0) } ?? .now,
                updatedAt: (dayRow["updated_at"] as String?).flatMap { dateFormatter.date(from: $0) } ?? .now
            )
        }
    }

    private static func save(
        state: AppState,
        db: Database,
        encoder: JSONEncoder,
        dateFormatter: ISO8601DateFormatter
    ) throws {
        try db.execute(sql: "DELETE FROM work_sessions")
        try db.execute(sql: "DELETE FROM work_days")
        try db.execute(sql: "DELETE FROM settings WHERE key = ?", arguments: ["app_settings"])

        let settingsData = try encoder.encode(state.settings)
        let settingsJSON = String(decoding: settingsData, as: UTF8.self)
        try db.execute(
            sql: "INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)",
            arguments: ["app_settings", settingsJSON, dateFormatter.string(from: .now)]
        )

        for entry in state.entries where entry.hasMeaningfulContent {
            try db.execute(
                sql: """
                INSERT INTO work_days (
                    id, work_day_date, timezone_identifier, target_work_duration_minutes,
                    planned_break_duration_minutes, note, is_explicit_empty_day, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    entry.id.uuidString,
                    entry.date.id,
                    entry.timezoneIdentifier,
                    entry.targetWorkDurationMinutes,
                    entry.plannedBreakDurationMinutes,
                    entry.note,
                    entry.isExplicitEmptyDay,
                    dateFormatter.string(from: entry.createdAt),
                    dateFormatter.string(from: entry.updatedAt)
                ]
            )

            for session in entry.sessions.sorted(by: { $0.startTimestamp < $1.startTimestamp }) {
                try db.execute(
                    sql: """
                    INSERT INTO work_sessions (
                        id, work_day_id, assigned_work_day_date, start_timestamp,
                        end_timestamp, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        session.id.uuidString,
                        entry.id.uuidString,
                        session.assignedWorkDayDate.id,
                        dateFormatter.string(from: session.startTimestamp),
                        session.endTimestamp.map { dateFormatter.string(from: $0) },
                        dateFormatter.string(from: session.createdAt),
                        dateFormatter.string(from: session.updatedAt)
                    ]
                )
            }
        }
    }
}

extension LoqClockPersistence {
    static func memory(initialState: AppState = AppState()) -> LoqClockPersistence {
        final class Storage {
            var state: AppState

            init(state: AppState) {
                self.state = state
            }
        }

        let storage = Storage(state: initialState)

        return LoqClockPersistence(
            load: {
                storage.state
            },
            save: { state in
                storage.state = state
            }
        )
    }
}
