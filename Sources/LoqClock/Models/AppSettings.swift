import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var defaultTargetWorkDurationMinutes: Int
    var defaultLunchDurationMinutes: Int
    var launchAtLoginEnabled: Bool
    var launchAtLoginPromptHandled: Bool

    static let `default` = AppSettings(
        defaultTargetWorkDurationMinutes: 480,
        defaultLunchDurationMinutes: 60,
        launchAtLoginEnabled: false,
        launchAtLoginPromptHandled: false
    )

    private enum CodingKeys: String, CodingKey {
        case defaultTargetWorkDurationMinutes
        case defaultLunchDurationMinutes
        case launchAtLoginEnabled
        case launchAtLoginPromptHandled
    }

    init(
        defaultTargetWorkDurationMinutes: Int,
        defaultLunchDurationMinutes: Int,
        launchAtLoginEnabled: Bool = false,
        launchAtLoginPromptHandled: Bool = false
    ) {
        self.defaultTargetWorkDurationMinutes = defaultTargetWorkDurationMinutes
        self.defaultLunchDurationMinutes = defaultLunchDurationMinutes
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.launchAtLoginPromptHandled = launchAtLoginPromptHandled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultTargetWorkDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultTargetWorkDurationMinutes) ?? 480
        defaultLunchDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultLunchDurationMinutes) ?? 60
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
        launchAtLoginPromptHandled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginPromptHandled) ?? false
    }
}
