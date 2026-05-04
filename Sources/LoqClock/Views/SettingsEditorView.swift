import SwiftUI

struct SettingsEditorView: View {
    let settings: AppSettings
    let onCancel: () -> Void
    let onSave: (AppSettings) -> Void

    @State private var defaultTargetWorkDurationMinutes: Int
    @State private var defaultLunchDurationMinutes: Int

    init(
        settings: AppSettings,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AppSettings) -> Void
    ) {
        self.settings = settings
        self.onCancel = onCancel
        self.onSave = onSave
        _defaultTargetWorkDurationMinutes = State(initialValue: settings.defaultTargetWorkDurationMinutes)
        _defaultLunchDurationMinutes = State(initialValue: settings.defaultLunchDurationMinutes)
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    private func persist() {
        onSave(
            AppSettings(
                defaultTargetWorkDurationMinutes: defaultTargetWorkDurationMinutes,
                defaultLunchDurationMinutes: defaultLunchDurationMinutes
            )
        )
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainder)m"
    }
}
