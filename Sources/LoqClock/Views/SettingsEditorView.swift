import AppKit
import SwiftUI

struct SettingsEditorView: View {
    let settings: AppSettings
    let launchAtLoginErrorMessage: String?
    let updateCheckErrorMessage: String?
    let updateCheckStatusMessage: String?
    let onCancel: () -> Void
    let onSave: (AppSettings) -> Void
    let onToggleLaunchAtLogin: (Bool) -> Bool
    let onToggleAutomaticUpdates: (Bool) -> Void
    let onManualCheckForUpdates: () -> Void
    let onResetTrackingData: () -> Void
    let onResetEverything: () -> Void
    let onRestoreLatestBackup: () -> Void

    @State private var defaultTargetWorkDurationMinutes: Int
    @State private var defaultLunchDurationMinutes: Int
    @State private var launchAtLoginEnabled: Bool
    @State private var automaticallyCheckForUpdates: Bool
    @State private var liveBreakDeductionThresholdMinutes: Int
    @State private var notificationsEnabled: Bool
    @State private var remindersEnabled: Bool
    @State private var automaticBackupsEnabled: Bool
    @State private var selectedSection: SettingsSection = .general

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case timeTracking = "Time Tracking"
        case notifications = "Notifications"
        case backupExport = "Backup & Export"
        case analytics = "Analytics"
        case updates = "Updates"
        case permissions = "Permissions"
        case advanced = "Advanced / Data Reset"

        var id: String { rawValue }
    }

    init(
        settings: AppSettings,
        launchAtLoginErrorMessage: String?,
        updateCheckErrorMessage: String?,
        updateCheckStatusMessage: String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AppSettings) -> Void,
        onToggleLaunchAtLogin: @escaping (Bool) -> Bool,
        onToggleAutomaticUpdates: @escaping (Bool) -> Void,
        onManualCheckForUpdates: @escaping () -> Void,
        onResetTrackingData: @escaping () -> Void,
        onResetEverything: @escaping () -> Void,
        onRestoreLatestBackup: @escaping () -> Void
    ) {
        self.settings = settings
        self.launchAtLoginErrorMessage = launchAtLoginErrorMessage
        self.updateCheckErrorMessage = updateCheckErrorMessage
        self.updateCheckStatusMessage = updateCheckStatusMessage
        self.onCancel = onCancel
        self.onSave = onSave
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onToggleAutomaticUpdates = onToggleAutomaticUpdates
        self.onManualCheckForUpdates = onManualCheckForUpdates
        self.onResetTrackingData = onResetTrackingData
        self.onResetEverything = onResetEverything
        self.onRestoreLatestBackup = onRestoreLatestBackup
        _defaultTargetWorkDurationMinutes = State(initialValue: settings.defaultTargetWorkDurationMinutes)
        _defaultLunchDurationMinutes = State(initialValue: settings.defaultLunchDurationMinutes)
        _launchAtLoginEnabled = State(initialValue: settings.launchAtLoginEnabled)
        _automaticallyCheckForUpdates = State(initialValue: settings.automaticallyCheckForUpdates)
        _liveBreakDeductionThresholdMinutes = State(initialValue: settings.liveBreakDeductionThresholdMinutes)
        _notificationsEnabled = State(initialValue: settings.notificationsEnabled)
        _remindersEnabled = State(initialValue: settings.remindersEnabled)
        _automaticBackupsEnabled = State(initialValue: settings.automaticBackupsEnabled)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 8)

                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Text(section.rawValue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                selectedSection == section ? Color.primary.opacity(0.10) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Close") {
                    onCancel()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
            .frame(width: 190)
            .background(.thinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    settingsContent

                    if let launchAtLoginErrorMessage {
                        Text(launchAtLoginErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let updateCheckErrorMessage {
                        Text(updateCheckErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let updateCheckStatusMessage {
                        Text(updateCheckStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("Changes are saved automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 470)
        .onChange(of: defaultTargetWorkDurationMinutes) { _, newValue in
            defaultTargetWorkDurationMinutes = max(0, min(960, newValue))
            persist()
        }
        .onChange(of: defaultLunchDurationMinutes) { _, newValue in
            defaultLunchDurationMinutes = max(0, min(240, newValue))
            persist()
        }
        .onChange(of: launchAtLoginEnabled) { _, newValue in
            launchAtLoginEnabled = onToggleLaunchAtLogin(newValue)
        }
        .onChange(of: automaticallyCheckForUpdates) { _, newValue in
            onToggleAutomaticUpdates(newValue)
            persist()
        }
        .onChange(of: liveBreakDeductionThresholdMinutes) { _, newValue in
            liveBreakDeductionThresholdMinutes = max(0, min(960, newValue))
            persist()
        }
        .onChange(of: notificationsEnabled) { _, _ in
            persist()
        }
        .onChange(of: remindersEnabled) { _, _ in
            persist()
        }
        .onChange(of: automaticBackupsEnabled) { _, _ in
            persist()
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .general:
            SettingsSectionContent(title: "General") {
                Toggle("Launch LoqClock automatically at login", isOn: $launchAtLoginEnabled)
                Text("LoqClock stays local and uses an icon-only menu bar presence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .timeTracking:
            SettingsSectionContent(title: "Time Tracking") {
                DurationAdjusterRow(
                    title: "Default Target Work",
                    minutes: $defaultTargetWorkDurationMinutes,
                    range: 0...960
                )

                DurationAdjusterRow(
                    title: "Default Planned Break",
                    minutes: $defaultLunchDurationMinutes,
                    range: 0...240
                )

                DurationAdjusterRow(
                    title: "Live Break Threshold",
                    minutes: $liveBreakDeductionThresholdMinutes,
                    range: 0...960
                )

                Text("Single active sessions subtract the planned break only after this threshold. Multi-session days use gaps as breaks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .notifications:
            SettingsSectionContent(title: "Notifications") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                Toggle("Enable reminders", isOn: $remindersEnabled)
                Text("Scheduling hooks are stored locally here; delivery rules are the next notifications layer.")
                    .foregroundStyle(.secondary)
            }
        case .backupExport:
            SettingsSectionContent(title: "Backup & Export") {
                Toggle("Enable automatic local backups", isOn: $automaticBackupsEnabled)
                Text("LoqClock creates local JSON recovery backups before risky changes and keeps the latest five.")
                    .foregroundStyle(.secondary)

                Button("Restore Latest Backup…") {
                    confirmRestoreLatestBackup()
                }
                .buttonStyle(.bordered)
            }
        case .analytics:
            SettingsSectionContent(title: "Analytics") {
                Text("Analytics color and timeframe preferences will live here as charts mature.")
                    .foregroundStyle(.secondary)
            }
        case .updates:
            SettingsSectionContent(title: "Updates") {
                Toggle("Check for updates automatically", isOn: $automaticallyCheckForUpdates)

                Button("Check for Updates…") {
                    onManualCheckForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        case .permissions:
            SettingsSectionContent(title: "Permissions") {
                Text("No account, network permission, cloud sync, telemetry, calendar, contacts, or location access is required for time tracking.")
                    .foregroundStyle(.secondary)
            }
        case .advanced:
            SettingsSectionContent(title: "Advanced / Data Reset") {
                Text("Reset actions create a local recovery backup first and require typing RESET.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Reset Tracking Data", role: .destructive) {
                        confirmReset(
                            title: "Reset tracking data?",
                            message: "This removes all workdays and sessions after creating a recovery backup.",
                            onConfirm: onResetTrackingData
                        )
                    }

                    Button("Reset Everything", role: .destructive) {
                        confirmReset(
                            title: "Reset everything?",
                            message: "This removes tracking data and restores app settings after creating a recovery backup.",
                            onConfirm: onResetEverything
                        )
                    }
                }
            }
        }
    }

    private func persist() {
        onSave(
            AppSettings(
                defaultTargetWorkDurationMinutes: defaultTargetWorkDurationMinutes,
                defaultLunchDurationMinutes: defaultLunchDurationMinutes,
                launchAtLoginEnabled: launchAtLoginEnabled,
                launchAtLoginPromptHandled: settings.launchAtLoginPromptHandled,
                automaticallyCheckForUpdates: automaticallyCheckForUpdates,
                lastSuccessfulUpdateCheckAt: settings.lastSuccessfulUpdateCheckAt,
                liveBreakDeductionThresholdMinutes: liveBreakDeductionThresholdMinutes,
                onboardingCompleted: settings.onboardingCompleted,
                notificationsEnabled: notificationsEnabled,
                remindersEnabled: remindersEnabled,
                automaticBackupsEnabled: automaticBackupsEnabled
            )
        )
    }

    private func confirmReset(title: String, message: String, onConfirm: () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "\(message)\n\nType RESET to continue."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = textField

        guard alert.runModal() == .alertSecondButtonReturn,
              textField.stringValue == "RESET" else {
            return
        }

        onConfirm()
    }

    private func confirmRestoreLatestBackup() {
        let alert = NSAlert()
        alert.messageText = "Restore latest backup?"
        alert.informativeText = "LoqClock will create a recovery backup of the current state first, then restore the newest local JSON backup."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Restore")

        guard alert.runModal() == .alertSecondButtonReturn else {
            return
        }

        onRestoreLatestBackup()
    }
}

private struct SettingsSectionContent<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
