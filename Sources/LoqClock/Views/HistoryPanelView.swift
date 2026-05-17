import SwiftUI

struct HistoryPanelView: View {
    @Binding var selectedDate: Date
    let entries: [WorkDayEntry]
    let recentEntries: [WorkDayEntry]
    let calendar: Calendar
    let calculator: WorkTimeCalculator
    let onClose: () -> Void
    let onOpenSelectedDate: () -> Void
    let onOpenEntry: (LocalDay) -> Void

    var body: some View {
        let monthEntries = entriesInSelectedMonth()

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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(monthTitle)
                            .font(.headline)

                        Spacer()

                        Button {
                            shiftSelectedMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            shiftSelectedMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.borderless)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(monthCells(), id: \.self) { day in
                            if let day {
                                Button {
                                    open(day)
                                } label: {
                                    VStack(spacing: 3) {
                                        Text("\(day.day)")
                                            .font(.caption.weight(.semibold))

                                        Circle()
                                            .fill(entry(for: day) == nil ? Color.clear : Color.accentColor)
                                            .frame(width: 4, height: 4)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 30)
                                    .background(
                                        day == LocalDay(date: selectedDate, calendar: calendar)
                                            ? Color.accentColor.opacity(0.14)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(minHeight: 30)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Month Summary")
                        .font(.headline)

                    HistorySummaryRow(title: "Entries", value: "\(monthEntries.count)")
                    HistorySummaryRow(
                        title: "Balance",
                        value: signedDurationText(
                            calculator.monthBalanceMinutes(
                                for: entries,
                                relativeTo: selectedDate
                            )
                        )
                    )
                }
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
        .frame(width: 460)
    }

    private func historySubtitle(for entry: WorkDayEntry) -> String {
        let start = entry.startTime?.formatted(date: .omitted, time: .shortened) ?? "No start"
        let end = entry.endTime?.formatted(date: .omitted, time: .shortened) ?? "No end"
        let sessionCount = entry.sessions.count == 1 ? "1 session" : "\(entry.sessions.count) sessions"
        return "\(start) - \(end) | \(sessionCount)"
    }

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private func monthCells() -> [LocalDay?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let dayRange = calendar.range(of: .day, in: .month, for: selectedDate) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCells = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = dayRange.compactMap { day -> LocalDay? in
            calendar.date(bySetting: .day, value: day, of: monthInterval.start)
                .map { LocalDay(date: $0, calendar: calendar) }
        }

        return Array(repeating: nil, count: leadingEmptyCells) + days
    }

    private func entriesInSelectedMonth() -> [WorkDayEntry] {
        entries.filter { entry in
            guard let date = entry.date.date(in: calendar) else {
                return false
            }

            return calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        }
    }

    private func entry(for day: LocalDay) -> WorkDayEntry? {
        entries.first { $0.date == day }
    }

    private func open(_ day: LocalDay) {
        selectedDate = day.date(in: calendar) ?? selectedDate
        onOpenEntry(day)
    }

    private func shiftSelectedMonth(by value: Int) {
        selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
    }

    private func signedDurationText(_ minutes: Int) -> String {
        let prefix = minutes < 0 ? "-" : "+"
        let absoluteMinutes = abs(minutes)
        let hours = absoluteMinutes / 60
        let remainingMinutes = absoluteMinutes % 60
        let duration = remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
        return "\(prefix)\(duration)"
    }
}

private struct HistorySummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
