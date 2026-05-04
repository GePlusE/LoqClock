import SwiftUI

struct SettingsEditorView: View {
    let settings: AppSettings
    let launchAtLoginErrorMessage: String?
    let onCancel: () -> Void
    let onSave: (AppSettings) -> Void
    let onToggleLaunchAtLogin: (Bool) -> Bool

    @State private var defaultTargetWorkDurationMinutes: Int
    @State private var defaultLunchDurationMinutes: Int
    @State private var launchAtLoginEnabled: Bool

    init(
        settings: AppSettings,
        launchAtLoginErrorMessage: String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AppSettings) -> Void,
        onToggleLaunchAtLogin: @escaping (Bool) -> Bool
    ) {
        self.settings = settings
        self.launchAtLoginErrorMessage = launchAtLoginErrorMessage
        self.onCancel = onCancel
        self.onSave = onSave
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        _defaultTargetWorkDurationMinutes = State(initialValue: settings.defaultTargetWorkDurationMinutes)
        _defaultLunchDurationMinutes = State(initialValue: settings.defaultLunchDurationMinutes)
        _launchAtLoginEnabled = State(initialValue: settings.launchAtLoginEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Close") {
                    onCancel()
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    DurationAdjusterRow(
                        title: "Default Target Work",
                        minutes: $defaultTargetWorkDurationMinutes,
                        range: 0...960
                    )

                    DurationAdjusterRow(
                        title: "Default Lunch",
                        minutes: $defaultLunchDurationMinutes,
                        range: 0...240
                    )

                    Toggle("Launch LoqClock automatically at login", isOn: $launchAtLoginEnabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let launchAtLoginErrorMessage {
                Text(launchAtLoginErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("Changes are saved automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Done") {
                    onCancel()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
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
    }

    private func persist() {
        onSave(
            AppSettings(
                defaultTargetWorkDurationMinutes: defaultTargetWorkDurationMinutes,
                defaultLunchDurationMinutes: defaultLunchDurationMinutes,
                launchAtLoginEnabled: launchAtLoginEnabled,
                launchAtLoginPromptHandled: settings.launchAtLoginPromptHandled
            )
        )
    }
}
