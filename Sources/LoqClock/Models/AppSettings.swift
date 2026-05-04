import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var defaultTargetWorkDurationMinutes: Int
    var defaultLunchDurationMinutes: Int

    static let `default` = AppSettings(
        defaultTargetWorkDurationMinutes: 480,
        defaultLunchDurationMinutes: 60
    )
}
