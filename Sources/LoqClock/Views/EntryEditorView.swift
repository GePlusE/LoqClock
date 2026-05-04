import SwiftUI

struct EntryEditorView: View {
    let day: LocalDay
    let settings: AppSettings
    let existingEntry: WorkDayEntry?
    let calendar: Calendar
    let onSave: (WorkDayEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var targetWorkDurationMinutes: Int
    @State private var lunchDurationMinutes: Int
    @State private var notes: String

    init(
        day: LocalDay,
        settings: AppSettings,
        existingEntry: WorkDayEntry?,
        calendar: Calendar,
        onSave: @escaping (WorkDayEntry) -> Void
    ) {
        self.day = day
        self.settings = settings
        self.existingEntry = existingEntry
        self.calendar = calendar
        self.onSave = onSave

        let baseline = day.date(in: calendar) ?? .now
        let defaultStart = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: baseline
        ) ?? baseline
        let defaultEnd = calendar.date(
            byAdding: .minute,
            value: settings.defaultTargetWorkDurationMinutes + settings.defaultLunchDurationMinutes,
            to: defaultStart
        ) ?? defaultStart

        _hasStartTime = State(initialValue: existingEntry?.startTime != nil)
        _startTime = State(initialValue: existingEntry?.startTime ?? defaultStart)
        _hasEndTime = State(initialValue: existingEntry?.endTime != nil)
        _endTime = State(initialValue: existingEntry?.endTime ?? defaultEnd)
        _targetWorkDurationMinutes = State(initialValue: existingEntry?.targetWorkDurationMinutes ?? settings.defaultTargetWorkDurationMinutes)
        _lunchDurationMinutes = State(initialValue: existingEntry?.lunchDurationMinutes ?? settings.defaultLunchDurationMinutes)
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Today")
                .font(.title3.weight(.semibold))

            Form {
                Toggle("Has Start Time", isOn: $hasStartTime)

                if hasStartTime {
                    DatePicker(
                        "Start",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle("Has End Time", isOn: $hasEndTime)

                if hasEndTime {
                    DatePicker(
                        "End",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                }

                Stepper(
                    "Target Work: \(durationText(targetWorkDurationMinutes))",
                    value: $targetWorkDurationMinutes,
                    in: 0...960,
                    step: 15
                )

                Stepper(
                    "Lunch: \(durationText(lunchDurationMinutes))",
                    value: $lunchDurationMinutes,
                    in: 0...240,
                    step: 15
                )

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    onSave(makeEntry())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func makeEntry() -> WorkDayEntry {
        WorkDayEntry(
            id: existingEntry?.id ?? UUID(),
            date: day,
            startTime: hasStartTime ? startTime : nil,
            endTime: hasEndTime ? endTime : nil,
            targetWorkDurationMinutes: targetWorkDurationMinutes,
            lunchDurationMinutes: lunchDurationMinutes,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            createdAt: existingEntry?.createdAt ?? .now,
            updatedAt: .now
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
