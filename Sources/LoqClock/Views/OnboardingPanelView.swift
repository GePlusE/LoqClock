import SwiftUI

struct OnboardingPanelView: View {
    let onComplete: (_ launchAtLogin: Bool, _ notifications: Bool, _ reminders: Bool, _ updates: Bool, _ backups: Bool) -> Void
    let onSkip: () -> Void

    @State private var launchAtLogin = false
    @State private var notifications = false
    @State private var reminders = false
    @State private var updates = false
    @State private var backups = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to LoqClock")
                        .font(.title3.weight(.semibold))

                    Text("Local-only work-time tracking with no accounts, no cloud sync, and no telemetry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Toggle("Enable notifications", isOn: $notifications)
                    Toggle("Enable reminders", isOn: $reminders)
                    Toggle("Check for updates automatically", isOn: $updates)
                    Toggle("Enable automatic local backups", isOn: $backups)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("You can change these choices later in Settings. Time tracking remains fully local either way.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Skip All") {
                    onSkip()
                }

                Spacer()

                Button("Start Using LoqClock") {
                    onComplete(launchAtLogin, notifications, reminders, updates, backups)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
