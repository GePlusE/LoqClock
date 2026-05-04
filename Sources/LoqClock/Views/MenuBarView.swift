import SwiftUI

struct MenuBarView: View {
    @Bindable var store: LoqClockStore

    private var today: LocalDay {
        LocalDay(date: .now, calendar: store.calendar)
    }

    private var todaysEntry: WorkDayEntry? {
        store.entry(for: today)
    }

    private var totalBalanceMinutes: Int {
        store.calculator.totalBalanceMinutes(for: store.entries)
    }

    private var weekBalanceMinutes: Int {
        store.calculator.weekBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    private var monthBalanceMinutes: Int {
        store.calculator.monthBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    private var yearBalanceMinutes: Int {
        store.calculator.yearBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LoqClock")
                    .font(.title3.weight(.semibold))

                Text("Core calculations and local persistence are wired up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                PlaceholderRow(title: "Stored Entries", value: "\(store.entries.count)")
                PlaceholderRow(title: "Default Target", value: durationText(store.settings.defaultTargetWorkDurationMinutes))
                PlaceholderRow(title: "Default Lunch", value: durationText(store.settings.defaultLunchDurationMinutes))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let todaysEntry {
                    PlaceholderRow(
                        title: "Net Worked Today",
                        value: durationText(store.calculator.netWorkedMinutes(for: todaysEntry))
                    )
                    PlaceholderRow(
                        title: "Daily Balance",
                        value: signedDurationText(store.calculator.dailyBalanceMinutes(for: todaysEntry))
                    )
                    PlaceholderRow(
                        title: "Leave at 0 Today",
                        value: timeText(store.calculator.leaveTimeForZeroToday(for: todaysEntry))
                    )
                    PlaceholderRow(
                        title: "Leave at 0 Week",
                        value: timeText(
                            store.calculator.leaveTimeForZeroWeek(
                                todayEntry: todaysEntry,
                                allEntries: store.entries
                            )
                        )
                    )
                } else {
                    PlaceholderRow(title: "Today", value: "No local entry")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                PlaceholderRow(title: "Total Balance", value: signedDurationText(totalBalanceMinutes))
                PlaceholderRow(title: "Week Balance", value: signedDurationText(weekBalanceMinutes))
                PlaceholderRow(title: "Month Balance", value: signedDurationText(monthBalanceMinutes))
                PlaceholderRow(title: "Year Balance", value: signedDurationText(yearBalanceMinutes))
            }

            Divider()

            HStack(spacing: 10) {
                Button(todaysEntry == nil ? "Create Today" : "Refresh Today") {
                    var entry = store.ensureEntry(for: today)
                    entry.startTime = entry.startTime ?? .now
                    entry.endTime = entry.endTime ?? .now.addingTimeInterval(TimeInterval((entry.targetWorkDurationMinutes + entry.lunchDurationMinutes) * 60))
                    store.createOrUpdateEntry(entry)
                }

                Button("Delete Today") {
                    store.deleteEntry(for: today)
                }
                .disabled(todaysEntry == nil)
            }

            Text("Reference: PRODUCT_SPEC.md")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 320)
        .background(.regularMaterial)
    }

    private func durationText(_ minutes: Int) -> String {
        let absoluteMinutes = abs(minutes)
        let hours = absoluteMinutes / 60
        let remainingMinutes = absoluteMinutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func signedDurationText(_ minutes: Int) -> String {
        let prefix = minutes < 0 ? "-" : "+"
        return "\(prefix)\(durationText(minutes))"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct PlaceholderRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
