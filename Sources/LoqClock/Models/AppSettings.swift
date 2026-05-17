import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var defaultTargetWorkDurationMinutes: Int
    var defaultLunchDurationMinutes: Int
    var launchAtLoginEnabled: Bool
    var launchAtLoginPromptHandled: Bool
    var automaticallyCheckForUpdates: Bool
    var lastSuccessfulUpdateCheckAt: Date?
    var liveBreakDeductionThresholdMinutes: Int
    var onboardingCompleted: Bool
    var notificationsEnabled: Bool
    var remindersEnabled: Bool
    var automaticBackupsEnabled: Bool

    static let `default` = AppSettings(
        defaultTargetWorkDurationMinutes: 480,
        defaultLunchDurationMinutes: 60,
        launchAtLoginEnabled: false,
        launchAtLoginPromptHandled: false,
        automaticallyCheckForUpdates: false,
        lastSuccessfulUpdateCheckAt: nil,
        liveBreakDeductionThresholdMinutes: 360,
        onboardingCompleted: false,
        notificationsEnabled: false,
        remindersEnabled: false,
        automaticBackupsEnabled: false
    )

    private enum CodingKeys: String, CodingKey {
        case defaultTargetWorkDurationMinutes
        case defaultLunchDurationMinutes
        case launchAtLoginEnabled
        case launchAtLoginPromptHandled
        case automaticallyCheckForUpdates
        case lastSuccessfulUpdateCheckAt
        case liveBreakDeductionThresholdMinutes
        case onboardingCompleted
        case notificationsEnabled
        case remindersEnabled
        case automaticBackupsEnabled
    }

    init(
        defaultTargetWorkDurationMinutes: Int,
        defaultLunchDurationMinutes: Int,
        launchAtLoginEnabled: Bool = false,
        launchAtLoginPromptHandled: Bool = false,
        automaticallyCheckForUpdates: Bool = false,
        lastSuccessfulUpdateCheckAt: Date? = nil,
        liveBreakDeductionThresholdMinutes: Int = 360,
        onboardingCompleted: Bool = false,
        notificationsEnabled: Bool = false,
        remindersEnabled: Bool = false,
        automaticBackupsEnabled: Bool = false
    ) {
        self.defaultTargetWorkDurationMinutes = defaultTargetWorkDurationMinutes
        self.defaultLunchDurationMinutes = defaultLunchDurationMinutes
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.launchAtLoginPromptHandled = launchAtLoginPromptHandled
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.lastSuccessfulUpdateCheckAt = lastSuccessfulUpdateCheckAt
        self.liveBreakDeductionThresholdMinutes = liveBreakDeductionThresholdMinutes
        self.onboardingCompleted = onboardingCompleted
        self.notificationsEnabled = notificationsEnabled
        self.remindersEnabled = remindersEnabled
        self.automaticBackupsEnabled = automaticBackupsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultTargetWorkDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultTargetWorkDurationMinutes) ?? 480
        defaultLunchDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultLunchDurationMinutes) ?? 60
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
        launchAtLoginPromptHandled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginPromptHandled) ?? false
        automaticallyCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .automaticallyCheckForUpdates) ?? false
        lastSuccessfulUpdateCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulUpdateCheckAt)
        liveBreakDeductionThresholdMinutes = try container.decodeIfPresent(Int.self, forKey: .liveBreakDeductionThresholdMinutes) ?? 360
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        automaticBackupsEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticBackupsEnabled) ?? false
    }
}
