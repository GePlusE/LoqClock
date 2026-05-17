import Foundation

struct LoqClockBackupService {
    var createBackup: (AppState, String, Date) throws -> URL?
    var latestBackup: () throws -> URL?
    var loadBackup: (URL) throws -> AppState

    static func live(fileManager: FileManager = .default) -> LoqClockBackupService {
        LoqClockBackupService(
            createBackup: { state, reason, now in
                let backupDirectory = backupDirectory(fileManager: fileManager)
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601

                let data = try encoder.encode(state)
                let filename = "LoqClock-backup-\(filenameTimestamp(for: now))-\(safeReason(reason)).json"
                let url = backupDirectory.appending(path: filename, directoryHint: .notDirectory)
                try data.write(to: url, options: .atomic)
                try pruneBackups(in: backupDirectory, fileManager: fileManager)
                return url
            },
            latestBackup: {
                try backupFiles(in: backupDirectory(fileManager: fileManager), fileManager: fileManager).first
            },
            loadBackup: { url in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let data = try Data(contentsOf: url)
                return try decoder.decode(AppState.self, from: data)
            }
        )
    }

    static func disabled() -> LoqClockBackupService {
        LoqClockBackupService(
            createBackup: { _, _, _ in nil },
            latestBackup: { nil },
            loadBackup: { _ in AppState() }
        )
    }

    private static func backupDirectory(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return baseURL
            .appending(path: "LoqClock", directoryHint: .isDirectory)
            .appending(path: "Backups", directoryHint: .isDirectory)
    }

    private static func filenameTimestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
    }

    private static func safeReason(_ reason: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return reason
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowedCharacters.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
    }

    private static func pruneBackups(in directory: URL, fileManager: FileManager) throws {
        let backupFiles = try backupFiles(in: directory, fileManager: fileManager)

        for oldBackup in backupFiles.dropFirst(5) {
            try fileManager.removeItem(at: oldBackup)
        }
    }

    private static func backupFiles(in directory: URL, fileManager: FileManager) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("LoqClock-backup-") }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }
}
