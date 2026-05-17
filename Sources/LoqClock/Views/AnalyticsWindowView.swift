import SwiftUI

struct AnalyticsWindowView: View {
    @Bindable var store: LoqClockStore

    var body: some View {
        let now = Date()
        let total = store.calculator.totalBalanceMinutes(for: store.entries, now: now)
        let week = store.calculator.weekBalanceMinutes(for: store.entries, relativeTo: now, now: now)
        let month = store.calculator.monthBalanceMinutes(for: store.entries, relativeTo: now, now: now)
        let year = store.calculator.yearBalanceMinutes(for: store.entries, relativeTo: now, now: now)

        VStack(alignment: .leading, spacing: 18) {
            Text("Analytics")
                .font(.title2.weight(.semibold))

            Text("Session-aware summaries. Charts, heatmaps, date-range controls, and report export are the next analytics layer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AnalyticsMetricCard(title: "Total", value: signedDurationText(total))
                AnalyticsMetricCard(title: "Week", value: signedDurationText(week))
                AnalyticsMetricCard(title: "Month", value: signedDurationText(month))
                AnalyticsMetricCard(title: "Year", value: signedDurationText(year))
            }

            Divider()

            HStack {
                Text("Tracked Days")
                    .fontWeight(.semibold)

                Spacer()

                Text("\(store.entries.filter { !$0.sessions.isEmpty }.count)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func signedDurationText(_ minutes: Int) -> String {
        let prefix = minutes < 0 ? "-" : "+"
        return "\(prefix)\(durationText(minutes))"
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
}

private struct AnalyticsMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
