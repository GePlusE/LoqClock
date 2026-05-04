import SwiftUI

struct MenuBarView: View {
    @Bindable var store: LoqClockStore
    @State private var activePanel: ActivePanel?

    private enum ActivePanel {
        case entryEditor
        case settings
    }

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

    private var isTodayInProgress: Bool {
        guard let todaysEntry else {
            return false
        }

        return todaysEntry.startTime != nil && todaysEntry.endTime == nil
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: isTodayInProgress ? 60 : 3600)) { context in
            VStack(alignment: .leading, spacing: 16) {
                if activePanel == .entryEditor {
                    EntryEditorView(
                        day: today,
                        settings: store.settings,
                        existingEntry: todaysEntry,
                        calendar: store.calendar,
                        onCancel: { activePanel = nil }
                    ) { entry in
                        store.createOrUpdateEntry(entry)
                    }
                } else if activePanel == .settings {
                    SettingsEditorView(
                        settings: store.settings,
                        onCancel: { activePanel = nil }
                    ) { settings in
                        store.updateSettings(settings)
                    }
                } else {
                    overviewContent(now: context.date)
                }
            }
            .padding(18)
            .frame(width: activePanel == nil ? 320 : 360)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func overviewContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LoqClock")
                    .font(.title3.weight(.semibold))

                Text(isTodayInProgress ? "Today is running and updates live." : "Manual tracking with fast today actions.")
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
                    let extraBreakSummary = extraBreakSummary(for: todaysEntry)
                    let netWorked = store.calculator.netWorkedMinutes(for: todaysEntry, now: now)
                    let dailyBalance = store.calculator.dailyBalanceMinutes(for: todaysEntry, now: now)
                    PlaceholderRow(title: "Start", value: timeText(todaysEntry.startTime))
                    PlaceholderRow(
                        title: "End",
                        value: todaysEntry.endTime == nil && todaysEntry.startTime != nil ? "In progress" : timeText(todaysEntry.endTime)
                    )
                    PlaceholderRow(title: "Target", value: durationText(todaysEntry.targetWorkDurationMinutes))
                    PlaceholderRow(title: "Lunch", value: durationText(todaysEntry.lunchDurationMinutes))
                    if let extraBreakSummary {
                        PlaceholderRow(title: "Extra Breaks", value: extraBreakSummary)
                    }
                    PlaceholderRow(
                        title: "Net Worked Today",
                        value: durationText(netWorked)
                    )
                    PlaceholderRow(
                        title: "Daily Balance",
                        value: signedDurationText(dailyBalance)
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
                PlaceholderRow(title: "Total Balance", value: signedDurationText(store.calculator.totalBalanceMinutes(for: store.entries, now: now)))
                PlaceholderRow(title: "Week Balance", value: signedDurationText(store.calculator.weekBalanceMinutes(for: store.entries, relativeTo: now, now: now)))
                PlaceholderRow(title: "Month Balance", value: signedDurationText(store.calculator.monthBalanceMinutes(for: store.entries, relativeTo: now, now: now)))
                PlaceholderRow(title: "Year Balance", value: signedDurationText(store.calculator.yearBalanceMinutes(for: store.entries, relativeTo: now, now: now)))
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(isTodayInProgress ? "Restart Start" : "Start Day") {
                        store.startToday(now: now)
                    }

                    Button(isTodayInProgress ? "End Day" : "Set End Time") {
                        store.endToday(now: now)
                    }
                    .disabled(todaysEntry == nil && !isTodayInProgress)
                }

                HStack(spacing: 10) {
                    Button(todaysEntry == nil ? "Create Today" : "Edit Today") {
                        if todaysEntry == nil {
                            _ = store.ensureEntry(for: today)
                        }
                        activePanel = .entryEditor
                    }

                    if todaysEntry?.endTime != nil {
                        Button("Resume Today") {
                            store.clearTodayEndTime(now: now)
                        }
                    }

                    Button("Delete Today") {
                        store.deleteEntry(for: today)
                    }
                    .disabled(todaysEntry == nil)

                    Spacer()

                    Button("Settings") {
                        activePanel = .settings
                    }
                }
            }

            Text("Reference: PRODUCT_SPEC.md")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
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

    private func extraBreakSummary(for entry: WorkDayEntry) -> String? {
        guard !entry.additionalBreaks.isEmpty else {
            return nil
        }

        let totalMinutes = entry.additionalBreaks.reduce(0) { $0 + $1.durationMinutes }
        return "\(durationText(totalMinutes)) across \(entry.additionalBreaks.count)"
    }
}

private struct PlaceholderRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
