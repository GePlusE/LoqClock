import SwiftUI

struct EntryEditorView: View {
    let day: LocalDay
    let settings: AppSettings
    let existingEntry: WorkDayEntry?
    let calendar: Calendar
    let onCancel: () -> Void
    let onSave: (WorkDayEntry) -> Void

    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var targetWorkDurationMinutes: Int
    @State private var lunchDurationMinutes: Int
    @State private var additionalBreaks: [WorkBreak]
    @State private var notes: String

    init(
        day: LocalDay,
        settings: AppSettings,
        existingEntry: WorkDayEntry?,
        calendar: Calendar,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkDayEntry) -> Void
    ) {
        self.day = day
        self.settings = settings
        self.existingEntry = existingEntry
        self.calendar = calendar
        self.onCancel = onCancel
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
        _additionalBreaks = State(initialValue: existingEntry?.additionalBreaks ?? [])
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit Today")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Close") {
                    onCancel()
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Has Start Time", isOn: $hasStartTime)

                    if hasStartTime {
                        DatePicker(
                            "Start",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                    }

                    Toggle("Has End Time", isOn: $hasEndTime)

                    if hasEndTime {
                        DatePicker(
                            "End",
                            selection: $endTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    DurationAdjusterRow(
                        title: "Target Work",
                        minutes: $targetWorkDurationMinutes,
                        range: 0...960
                    )

                    DurationAdjusterRow(
                        title: "Lunch",
                        minutes: $lunchDurationMinutes,
                        range: 0...240
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if additionalBreaks.isEmpty {
                HStack {
                    Text("Additional Breaks")
                        .font(.headline)

                    Spacer()

                    Button("Add Break") {
                        additionalBreaks.append(
                            WorkBreak(
                                name: defaultBreakName(for: additionalBreaks.count),
                                durationMinutes: 5
                            )
                        )
                        persist()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Additional Breaks")
                                .font(.headline)

                            Spacer()

                            if additionalBreaks.count < 10 {
                                Button("Add Break") {
                                    additionalBreaks.append(
                                        WorkBreak(
                                            name: defaultBreakName(for: additionalBreaks.count),
                                            durationMinutes: 5
                                        )
                                    )
                                    persist()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        ForEach(Array(additionalBreaks.enumerated()), id: \.element.id) { index, _ in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField(
                                        "Break name",
                                        text: bindingForBreakName(at: index)
                                    )
                                    .textFieldStyle(.roundedBorder)

                                    Button("Remove") {
                                        additionalBreaks.remove(at: index)
                                        persist()
                                    }
                                    .buttonStyle(.borderless)
                                }

                                DurationAdjusterRow(
                                    title: "Duration",
                                    minutes: bindingForBreakDuration(at: index),
                                    range: 0...120
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
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
        .onChange(of: hasStartTime) { _, _ in
            persist()
        }
        .onChange(of: startTime) { _, _ in
            if hasStartTime {
                persist()
            }
        }
        .onChange(of: hasEndTime) { _, _ in
            persist()
        }
        .onChange(of: endTime) { _, _ in
            if hasEndTime {
                persist()
            }
        }
        .onChange(of: targetWorkDurationMinutes) { _, newValue in
            targetWorkDurationMinutes = max(0, min(960, newValue))
            persist()
        }
        .onChange(of: lunchDurationMinutes) { _, newValue in
            lunchDurationMinutes = max(0, min(240, newValue))
            persist()
        }
        .onChange(of: notes) { _, _ in
            persist()
        }
    }

    private func persist() {
        onSave(makeEntry())
    }

    private func makeEntry() -> WorkDayEntry {
        WorkDayEntry(
            id: existingEntry?.id ?? UUID(),
            date: day,
            startTime: hasStartTime ? startTime : nil,
            endTime: hasEndTime ? endTime : nil,
            targetWorkDurationMinutes: targetWorkDurationMinutes,
            lunchDurationMinutes: lunchDurationMinutes,
            additionalBreaks: additionalBreaks.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.durationMinutes > 0
            },
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            createdAt: existingEntry?.createdAt ?? .now,
            updatedAt: .now
        )
    }

    private func bindingForBreakName(at index: Int) -> Binding<String> {
        Binding(
            get: { additionalBreaks[index].name },
            set: { newValue in
                additionalBreaks[index].name = newValue
                persist()
            }
        )
    }

    private func bindingForBreakDuration(at index: Int) -> Binding<Int> {
        Binding(
            get: { additionalBreaks[index].durationMinutes },
            set: { newValue in
                additionalBreaks[index].durationMinutes = max(0, min(120, newValue))
                persist()
            }
        )
    }

    private func defaultBreakName(for index: Int) -> String {
        "Break \(index + 1)"
    }
}

struct DurationAdjusterRow: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    private let deltas = [-15, -1, 1, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(durationText(minutes))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(deltas, id: \.self) { delta in
                    Button(buttonLabel(for: delta)) {
                        minutes = min(range.upperBound, max(range.lowerBound, minutes + delta))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func buttonLabel(for delta: Int) -> String {
        delta > 0 ? "+\(delta)m" : "\(delta)m"
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
