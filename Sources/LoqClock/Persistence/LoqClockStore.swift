import Foundation
import Observation

@MainActor
@Observable
final class LoqClockStore {
    private(set) var settings: AppSettings
    private(set) var entries: [WorkDayEntry]

    private let persistence: LoqClockPersistence
    let calendar: Calendar
    let calculator: WorkTimeCalculator

    init(
        persistence: LoqClockPersistence = .live(),
        calendar: Calendar = .current
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.calculator = WorkTimeCalculator(calendar: calendar)

        let state = (try? persistence.load()) ?? AppState()
        self.settings = state.settings
        self.entries = state.entries.sorted { $0.date < $1.date }
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

    func deleteEntry(for day: LocalDay) {
        entries.removeAll(where: { $0.date == day })
        save()
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        save()
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
