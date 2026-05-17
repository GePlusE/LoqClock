import Foundation
import Observation
import AppKit

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

    init(
        persistence: LoqClockPersistence = .live(),
        calendar: Calendar = .current,
        launchAtLoginService: LaunchAtLoginService = .live(),
        appUpdateService: AppUpdateService = .live()
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.calculator = WorkTimeCalculator(calendar: calendar)
        self.transferService = EntryTransferService()
        self.launchAtLoginService = launchAtLoginService
        self.appUpdateService = appUpdateService

        let state = (try? persistence.load()) ?? AppState()
        var loadedSettings = state.settings
        loadedSettings.launchAtLoginEnabled = launchAtLoginService.currentState()
        self.settings = loadedSettings
        self.entries = state.entries.sorted { $0.date < $1.date }
    }

    var shouldShowLaunchAtLoginPrompt: Bool {
        !settings.launchAtLoginPromptHandled && !entries.isEmpty
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
        entry.touch(now)

        if let index = entries.firstIndex(where: { $0.date == entry.date }) {
            entry = WorkDayEntry(
                id: entries[index].id,
                date: entry.date,
                startTime: entry.startTime,
                endTime: entry.endTime,
                targetWorkDurationMinutes: entry.targetWorkDurationMinutes,
                lunchDurationMinutes: entry.lunchDurationMinutes,
                additionalBreaks: entry.additionalBreaks,
                notes: entry.notes,
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
        entries.removeAll(where: { $0.date == day })
        save()
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
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

        upsertEntry(for: today, now: now) { entry in
            entry.startTime = entry.startTime ?? now
            entry.endTime = nil
        }
    }

    func endToday(now: Date = .now) {
        let today = LocalDay(date: now, calendar: calendar)

        upsertEntry(for: today, now: now) { entry in
            entry.startTime = entry.startTime ?? now
            entry.endTime = now
        }
    }

    func clearTodayEndTime(now: Date = .now) {
        let today = LocalDay(date: now, calendar: calendar)

        guard entry(for: today) != nil else {
            return
        }

        upsertEntry(for: today, now: now) { entry in
            entry.endTime = nil
        }
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
        let fileURL = appStateURL(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return LoqClockPersistence(
            load: {
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    return AppState()
                }

                let data = try Data(contentsOf: fileURL)
                return try decoder.decode(AppState.self, from: data)
            },
            save: { state in
                let directoryURL = fileURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

                let data = try encoder.encode(state)
                try data.write(to: fileURL, options: .atomic)
            }
        )
    }

    private static func appStateURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseURL
            .appending(path: "LoqClock", directoryHint: .isDirectory)
            .appending(path: "state.json", directoryHint: .notDirectory)
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
