import AppKit
import SwiftUI

struct AnalyticsWindowView: View {
    @Bindable var store: LoqClockStore
    @State private var timeframe: AnalyticsTimeframe = .month
    @State private var includeMissingDaysInAverages = false
    @State private var exportStatusMessage: String?

    private var reportService: AnalyticsReportService {
        AnalyticsReportService(calendar: store.calendar)
    }

    var body: some View {
        let now = Date()
        let summary = reportService.summary(
            entries: store.entries,
            timeframe: timeframe,
            includeMissingDaysInAverages: includeMissingDaysInAverages,
            relativeTo: now,
            now: now
        )

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Analytics")
                    .font(.title2.weight(.semibold))

                Spacer()

                Picker("Timeframe", selection: $timeframe) {
                    ForEach(AnalyticsTimeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AnalyticsMetricCard(title: "Balance", value: signedDurationText(summary.totalBalanceMinutes))
                AnalyticsMetricCard(title: "Tracked Days", value: "\(summary.trackedDays)")
                AnalyticsMetricCard(title: "Review Days", value: "\(summary.reviewDays)")
                AnalyticsMetricCard(title: "Avg Net", value: durationText(summary.averageNetWorkedMinutes))
            }

            HStack {
                Toggle("Include missing days in averages", isOn: $includeMissingDaysInAverages)

                Spacer()

                Button("Export CSV") {
                    exportCSV(summary: summary)
                }

                Button("Export PDF") {
                    exportPDF(summary: summary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily Rows")
                    .font(.headline)

                if summary.rows.isEmpty {
                    Text("No entries in this timeframe.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.rows.suffix(10), id: \.date) { row in
                        HStack {
                            Text(row.date.id)
                                .fontWeight(.semibold)

                            Spacer()

                            Text("\(row.sessions) sessions")
                                .foregroundStyle(.secondary)

                            Text(signedDurationText(row.balanceMinutes))
                                .frame(width: 72, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if let exportStatusMessage {
                Text(exportStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    private func exportCSV(summary: AnalyticsReportSummary) {
        export(
            data: reportService.csvData(summary: summary),
            fileName: "LoqClock-analytics-\(summary.timeframe.rawValue.lowercased()).csv",
            successMessage: "Exported analytics CSV."
        )
    }

    private func exportPDF(summary: AnalyticsReportSummary) {
        export(
            data: reportService.pdfData(summary: summary),
            fileName: "LoqClock-analytics-\(summary.timeframe.rawValue.lowercased()).pdf",
            successMessage: "Exported analytics PDF."
        )
    }

    private func export(data: Data, fileName: String, successMessage: String) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileName

        guard panel.runModal() == .OK, let url = panel.url else {
            exportStatusMessage = "Export cancelled."
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            exportStatusMessage = successMessage
        } catch {
            exportStatusMessage = error.localizedDescription
        }
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
