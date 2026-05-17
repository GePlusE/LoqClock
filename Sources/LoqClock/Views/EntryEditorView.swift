import SwiftUI

struct EntryEditorView: View {
    let day: LocalDay
    let settings: AppSettings
    let existingEntry: WorkDayEntry?
    let calendar: Calendar
    let onCancel: () -> Void
    let onSave: (WorkDayEntry) -> Void

    @State private var sessions: [WorkSessionDraft]
    @State private var targetWorkDurationMinutes: Int
    @State private var lunchDurationMinutes: Int
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit Today")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Close") {
                    onCancel()
                }
            }

            SessionListEditorView(
                sessions: $sessions,
                day: day,
                calendar: calendar,
                defaultDurationMinutes: targetWorkDurationMinutes + lunchDurationMinutes
            )

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
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
        .frame(width: 420)
        .onChange(of: sessions) { _, _ in
            persist()
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
            targetWorkDurationMinutes: targetWorkDurationMinutes,
            lunchDurationMinutes: lunchDurationMinutes,
            additionalBreaks: [],
            notes: WorkDayNote.sanitized(notes),
            sessions: sessions
                .map { $0.makeSession(for: day) }
                .sorted { $0.startTimestamp < $1.startTimestamp },
            createdAt: existingEntry?.createdAt ?? .now,
            updatedAt: .now
        )
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
