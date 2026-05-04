import SwiftUI

struct SettingsEditorView: View {
    let settings: AppSettings
    let onSave: (AppSettings) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var defaultTargetWorkDurationMinutes: Int
    @State private var defaultLunchDurationMinutes: Int

    init(
        settings: AppSettings,
        onSave: @escaping (AppSettings) -> Void
    ) {
        self.settings = settings
        self.onSave = onSave
        _defaultTargetWorkDurationMinutes = State(initialValue: settings.defaultTargetWorkDurationMinutes)
        _defaultLunchDurationMinutes = State(initialValue: settings.defaultLunchDurationMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title3.weight(.semibold))

            Form {
                Stepper(
                    "Default Target Work: \(durationText(defaultTargetWorkDurationMinutes))",
                    value: $defaultTargetWorkDurationMinutes,
                    in: 0...960,
                    step: 15
                )

                Stepper(
                    "Default Lunch: \(durationText(defaultLunchDurationMinutes))",
                    value: $defaultLunchDurationMinutes,
                    in: 0...240,
                    step: 15
                )
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    onSave(
                        AppSettings(
                            defaultTargetWorkDurationMinutes: defaultTargetWorkDurationMinutes,
                            defaultLunchDurationMinutes: defaultLunchDurationMinutes
                        )
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
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
