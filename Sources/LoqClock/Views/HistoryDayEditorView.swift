import SwiftUI

struct HistoryDayEditorView: View {
    let settings: AppSettings
    let calendar: Calendar
    let existingEntry: WorkDayEntry?
    let existingDates: Set<LocalDay>
    let onBack: () -> Void
    let onSave: (WorkDayEntry) -> Void
    let onDelete: (() -> Void)?

    @State private var sessions: [WorkSessionDraft]
    @State private var targetWorkDurationMinutes: Int
    @State private var lunchDurationMinutes: Int
    @State private var notes: String

    private let validator: WorkDayEntryValidator
    private let day: LocalDay

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
        self.day = day

        let baseline = day.date(in: calendar) ?? .now
        let defaultStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseline) ?? baseline
        let defaultEnd = calendar.date(
            byAdding: .minute,
            value: settings.defaultTargetWorkDurationMinutes + settings.defaultLunchDurationMinutes,
            to: defaultStart
        ) ?? defaultStart

        _sessions = State(
            initialValue: existingEntry?.sessions.map {
                WorkSessionDraft(session: $0, fallbackEndTime: defaultEnd)
            } ?? []
        )
        _targetWorkDurationMinutes = State(initialValue: existingEntry?.targetWorkDurationMinutes ?? settings.defaultTargetWorkDurationMinutes)
        _lunchDurationMinutes = State(initialValue: existingEntry?.lunchDurationMinutes ?? settings.defaultLunchDurationMinutes)
        _notes = State(initialValue: existingEntry?.notes ?? "")
    }

    var body: some View {
        let draftEntry = makeEntry(for: day)
        let reviewIssue = validator.primaryReviewIssue(for: draftEntry)
        let isFutureDay = day > LocalDay(date: .now, calendar: calendar)

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
                    HistoryReadOnlyRow(
                        title: "Date",
                        value: day.date(in: calendar)?.formatted(date: .abbreviated, time: .omitted) ?? day.id
                    )

                    HistoryReadOnlyRow(
                        title: "Time Zone",
                        value: existingEntry?.timezoneIdentifier ?? TimeZone.current.identifier
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isFutureDay {
                GroupBox {
                    Text("Future days can keep a note, but sessions can only be added once the day arrives.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                SessionListEditorView(
                    sessions: $sessions,
                    day: day,
                    calendar: calendar,
                    defaultDurationMinutes: targetWorkDurationMinutes + lunchDurationMinutes
                )
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    if isFutureDay {
                        Text("Target and planned break are applied when sessions are tracked.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        DurationAdjusterRow(
                            title: "Target Work",
                            minutes: $targetWorkDurationMinutes,
                            range: 0...960
                        )

                        if sessions.count <= 1 {
                            DurationAdjusterRow(
                                title: "Planned Break",
                                minutes: $lunchDurationMinutes,
                                range: 0...240
                            )
                        } else {
                            Text("Multi-session days use gaps between sessions as breaks.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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

            if let reviewIssue {
                Text("Needs review: \(reviewIssue.rawValue.replacingOccurrences(of: "_", with: " "))")
                    .font(.footnote)
                    .foregroundStyle(.orange)
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
                    onSave(makeEntry(for: day))
                    onBack()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func makeEntry(for day: LocalDay) -> WorkDayEntry {
        WorkDayEntry(
            id: existingEntry?.id ?? UUID(),
            date: day,
            timezoneIdentifier: existingEntry?.timezoneIdentifier ?? TimeZone.current.identifier,
            targetWorkDurationMinutes: targetWorkDurationMinutes,
            lunchDurationMinutes: lunchDurationMinutes,
            additionalBreaks: [],
            notes: WorkDayNote.sanitized(notes),
            sessions: day > LocalDay(date: .now, calendar: calendar)
                ? []
                : sessions
                    .map { $0.makeSession(for: day) }
                    .sorted { $0.startTimestamp < $1.startTimestamp },
            createdAt: existingEntry?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}

private struct HistoryReadOnlyRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
