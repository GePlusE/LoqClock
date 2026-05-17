import SwiftUI

struct WorkSessionDraft: Identifiable, Equatable {
    let id: UUID
    var startTime: Date
    var hasEndTime: Bool
    var endTime: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startTime: Date,
        hasEndTime: Bool,
        endTime: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startTime = startTime
        self.hasEndTime = hasEndTime
        self.endTime = endTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        session: WorkSession,
        fallbackEndTime: Date
    ) {
        self.id = session.id
        self.startTime = session.startTimestamp
        self.hasEndTime = session.endTimestamp != nil
        self.endTime = session.endTimestamp ?? fallbackEndTime
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
    }

    static func new(
        for day: LocalDay,
        calendar: Calendar,
        defaultDurationMinutes: Int
    ) -> WorkSessionDraft {
        let baseline = day.date(in: calendar) ?? .now
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseline) ?? baseline
        let end = calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: start) ?? start

        return WorkSessionDraft(
            startTime: start,
            hasEndTime: true,
            endTime: end
        )
    }

    func makeSession(for day: LocalDay, now: Date = .now) -> WorkSession {
        WorkSession(
            id: id,
            assignedWorkDayDate: day,
            startTimestamp: TimeNormalizer.roundedDownToMinute(startTime),
            endTimestamp: hasEndTime ? TimeNormalizer.roundedUpToMinuteIfNeeded(endTime) : nil,
            createdAt: createdAt,
            updatedAt: now
        )
    }
}

struct SessionListEditorView: View {
    @Binding var sessions: [WorkSessionDraft]
    let day: LocalDay
    let calendar: Calendar
    let defaultDurationMinutes: Int

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sessions")
                        .font(.headline)

                    Spacer()

                    Button("Add Session") {
                        sessions.append(
                            WorkSessionDraft.new(
                                for: day,
                                calendar: calendar,
                                defaultDurationMinutes: defaultDurationMinutes
                            )
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if sessions.isEmpty {
                    Text("No sessions yet. Add one when this day has tracked work.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions.indices, id: \.self) { index in
                        let sessionID = sessions[index].id

                        SessionDraftRow(
                            session: $sessions[index],
                            onDelete: {
                                sessions.removeAll { $0.id == sessionID }
                            }
                        )

                        if let lastIndex = sessions.indices.last, index != lastIndex {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: sessions) { _, _ in
            enforceSingleOpenSession()
        }
    }

    private func enforceSingleOpenSession() {
        var hasOpenSession = false

        for index in sessions.indices {
            if sessions[index].hasEndTime {
                continue
            }

            if hasOpenSession {
                sessions[index].hasEndTime = true
            } else {
                hasOpenSession = true
            }
        }
    }
}

private struct SessionDraftRow: View {
    @Binding var session: WorkSessionDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                "Start",
                selection: $session.startTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.field)

            Toggle("Has End Time", isOn: $session.hasEndTime)

            if session.hasEndTime {
                DatePicker(
                    "End",
                    selection: $session.endTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.field)
            }

            Button("Delete Session", role: .destructive) {
                onDelete()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
