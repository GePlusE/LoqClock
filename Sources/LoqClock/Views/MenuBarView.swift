import SwiftUI

struct MenuBarView: View {
    @Bindable var store: LoqClockStore

    private var today: LocalDay {
        LocalDay(date: .now, calendar: store.calendar)
    }

    private var todaysEntry: WorkDayEntry? {
        store.entry(for: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LoqClock")
                    .font(.title3.weight(.semibold))

                Text("Local persistence and domain models are ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                PlaceholderRow(title: "Stored Entries", value: "\(store.entries.count)")
                PlaceholderRow(title: "Default Target", value: durationText(store.settings.defaultTargetWorkDurationMinutes))
                PlaceholderRow(title: "Default Lunch", value: durationText(store.settings.defaultLunchDurationMinutes))
                PlaceholderRow(title: "Today", value: todaysEntry == nil ? "No local entry" : "Saved locally")
            }

            Divider()

            HStack(spacing: 10) {
                Button(todaysEntry == nil ? "Create Today" : "Refresh Today") {
                    var entry = store.ensureEntry(for: today)
                    entry.startTime = entry.startTime ?? .now
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
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
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
