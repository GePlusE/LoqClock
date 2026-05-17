import SwiftUI

struct HistoryPanelView: View {
    @Binding var selectedDate: Date
    let recentEntries: [WorkDayEntry]
    let calendar: Calendar
    let onClose: () -> Void
    let onOpenSelectedDate: () -> Void
    let onOpenEntry: (LocalDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Close") {
                    onClose()
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open a Day")
                        .font(.headline)

                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.field)

                    Button("Open Selected Day") {
                        onOpenSelectedDate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Entries")
                        .font(.headline)

                    if recentEntries.isEmpty {
                        Text("No saved workdays yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { entry in
                            Button {
                                onOpenEntry(entry.date)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.date.date(in: calendar)?.formatted(date: .abbreviated, time: .omitted) ?? entry.date.id)
                                            .foregroundStyle(.primary)

                                        Text(historySubtitle(for: entry))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Use this flow to backfill missing past days or correct saved workdays.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400)
    }

    private func historySubtitle(for entry: WorkDayEntry) -> String {
        let start = entry.startTime?.formatted(date: .omitted, time: .shortened) ?? "No start"
        let end = entry.endTime?.formatted(date: .omitted, time: .shortened) ?? "No end"
        return "\(start) - \(end)"
    }
}
