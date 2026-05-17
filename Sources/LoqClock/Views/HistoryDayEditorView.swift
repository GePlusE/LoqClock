import SwiftUI

struct HistoryDayEditorView: View {
    let settings: AppSettings
    let calendar: Calendar
    let existingEntry: WorkDayEntry?
    let existingDates: Set<LocalDay>
    let onBack: () -> Void
    let onSave: (WorkDayEntry) -> Void
    let onDelete: (() -> Void)?

    @State private var selectedDate: Date
    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var targetWorkDurationMinutes: Int
    @State private var lunchDurationMinutes: Int
    @State private var notes: String

    private let validator: WorkDayEntryValidator
    private let originalDate: LocalDay?

    init(
        day: LocalDay,
        settings: AppSettings,
        calendar: Calendar,
        existingEntry: WorkDayEntry?,
        existingDates: Set<LocalDay>,
        onBack: @escaping () -> Void,
        onSave: @escaping (WorkDayEntry) -> Void,
        onDelete: (() -> Void)?
    ) {
        self.settings = settings
        self.calendar = calendar
        self.existingEntry = existingEntry
        self.existingDates = existingDates
        self.onBack = onBack
        self.onSave = onSave
        self.onDelete = onDelete
        self.validator = WorkDayEntryValidator(calendar: calendar)
        self.originalDate = existingEntry?.date

        let baseline = day.date(in: calendar) ?? .now
        let defaultStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseline) ?? baseline
        let defaultEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: baseline) ?? baseline

        _selectedDate = State(initialValue: baseline)
        _hasStartTime = State(initialValue: existingEntry?.startTime != nil || day < LocalDay(date: .now, calendar: calendar))
        _startTime = State(initialValue: existingEntry?.startTime ?? defaultStart)
        _hasEndTime = State(initialValue: existingEntry?.endTime != nil || day < LocalDay(date: .now, calendar: calendar))
        _endTime = State(initialValue: existingEntry?.endTime ?? defaultEnd)
        _targetWorkDurationMinutes = State(initialValue: existingEntry?.targetWorkDurationMinutes ?? settings.defaultTargetWorkDurationMinutes)
        _lunchDurationMinutes = State(initialValue: existingEntry?.lunchDurationMinutes ?? settings.defaultLunchDurationMinutes)
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    var body: some View {
        let selectedLocalDay = LocalDay(date: selectedDate, calendar: calendar)
        let validationError = validator.validate(
            day: selectedLocalDay,
            startTime: resolvedStartTime,
            endTime: resolvedEndTime,
            lunchDurationMinutes: lunchDurationMinutes,
            additionalBreaks: [],
            existingDates: existingDates,
            originalDate: originalDate
        )
        let isPastDay = selectedLocalDay < LocalDay(date: .now, calendar: calendar)

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(existingEntry == nil ? "Add Day" : "Edit Day")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Back") {
                    onBack()
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.field)
                    .onChange(of: selectedDate) { _, newDate in
                        rebaseTimes(on: newDate)
                        if isPast(newDate) {
                            hasStartTime = true
                            hasEndTime = true
                        }
                    }

                    if isPastDay {
                        Text("Past days require both a start time and an end time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !isPastDay {
                        Toggle("Has Start Time", isOn: $hasStartTime)
                    }

                    if hasStartTime || isPastDay {
                        DatePicker(
                            "Start",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.field)
                    }

                    if !isPastDay {
                        Toggle("Has End Time", isOn: $hasEndTime)
                    }

                    if hasEndTime || isPastDay {
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

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    TextField("Optional note", text: $notes)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let validationError {
                Text(validationError.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                if let onDelete {
                    Button("Delete Day", role: .destructive) {
                        onDelete()
                        onBack()
                    }
                }

                Spacer()

                Button("Save Day") {
                    onSave(makeEntry(for: selectedLocalDay))
                    onBack()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var resolvedStartTime: Date? {
        let selectedLocalDay = LocalDay(date: selectedDate, calendar: calendar)
        let isPastDay = selectedLocalDay < LocalDay(date: .now, calendar: calendar)
        return (hasStartTime || isPastDay) ? startTime : nil
    }

    private var resolvedEndTime: Date? {
        let selectedLocalDay = LocalDay(date: selectedDate, calendar: calendar)
        let isPastDay = selectedLocalDay < LocalDay(date: .now, calendar: calendar)
        return (hasEndTime || isPastDay) ? endTime : nil
    }

    private func makeEntry(for day: LocalDay) -> WorkDayEntry {
        WorkDayEntry(
            id: existingEntry?.id ?? UUID(),
            date: day,
            startTime: resolvedStartTime,
            endTime: resolvedEndTime,
            targetWorkDurationMinutes: targetWorkDurationMinutes,
            lunchDurationMinutes: lunchDurationMinutes,
            additionalBreaks: [],
            notes: WorkDayNote.sanitized(notes),
            createdAt: existingEntry?.createdAt ?? .now,
            updatedAt: .now
        )
    }

    private func rebaseTimes(on newDate: Date) {
        startTime = rebasedTime(from: startTime, onto: newDate)
        endTime = rebasedTime(from: endTime, onto: newDate)
    }

    private func rebasedTime(from source: Date, onto targetDate: Date) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: source)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: targetDate
        ) ?? targetDate
    }

    private func isPast(_ date: Date) -> Bool {
        LocalDay(date: date, calendar: calendar) < LocalDay(date: .now, calendar: calendar)
    }

}
