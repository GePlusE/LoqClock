import AppKit
import CoreGraphics
import Foundation

enum AnalyticsTimeframe: String, CaseIterable, Identifiable, Sendable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }
}

struct AnalyticsReportRow: Equatable, Sendable {
    var date: LocalDay
    var sessions: Int
    var netWorkedMinutes: Int
    var targetMinutes: Int
    var balanceMinutes: Int
    var reviewIssue: WorkDayReviewIssue?
    var note: String?
}

struct AnalyticsReportSummary: Equatable, Sendable {
    var timeframe: AnalyticsTimeframe
    var totalBalanceMinutes: Int
    var trackedDays: Int
    var reviewDays: Int
    var averageNetWorkedMinutes: Int
    var rows: [AnalyticsReportRow]
}

struct AnalyticsReportService {
    let calendar: Calendar
    let calculator: WorkTimeCalculator
    let validator: WorkDayEntryValidator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.calculator = WorkTimeCalculator(calendar: calendar)
        self.validator = WorkDayEntryValidator(calendar: calendar)
    }

    func summary(
        entries: [WorkDayEntry],
        timeframe: AnalyticsTimeframe,
        includeMissingDaysInAverages: Bool,
        relativeTo referenceDate: Date = .now,
        now: Date = .now
    ) -> AnalyticsReportSummary {
        let filteredEntries = entries
            .filter { isEntry($0, in: timeframe, relativeTo: referenceDate) }
            .sorted { $0.date < $1.date }

        let rows = filteredEntries.map { entry in
            let reviewIssue = validator.primaryReviewIssue(for: entry, now: now)
            return AnalyticsReportRow(
                date: entry.date,
                sessions: entry.sessions.count,
                netWorkedMinutes: reviewIssue == nil ? calculator.netWorkedMinutes(for: entry, now: now) : 0,
                targetMinutes: entry.sessions.isEmpty ? 0 : entry.targetWorkDurationMinutes,
                balanceMinutes: reviewIssue == nil ? calculator.dailyBalanceMinutes(for: entry, now: now) : 0,
                reviewIssue: reviewIssue,
                note: entry.notes
            )
        }

        let validRows = rows.filter { $0.reviewIssue == nil }
        let trackedRows = validRows.filter { $0.sessions > 0 }
        let denominator = max(1, includeMissingDaysInAverages ? dayCount(for: timeframe, relativeTo: referenceDate, fallback: filteredEntries.count) : trackedRows.count)
        let netWorkedTotal = trackedRows.reduce(0) { $0 + $1.netWorkedMinutes }

        return AnalyticsReportSummary(
            timeframe: timeframe,
            totalBalanceMinutes: trackedRows.reduce(0) { $0 + $1.balanceMinutes },
            trackedDays: trackedRows.count,
            reviewDays: rows.filter { $0.reviewIssue != nil }.count,
            averageNetWorkedMinutes: netWorkedTotal / denominator,
            rows: rows
        )
    }

    func csvData(summary: AnalyticsReportSummary) -> Data {
        let rows = [
            ["timeframe", summary.timeframe.rawValue],
            ["total_balance_minutes", "\(summary.totalBalanceMinutes)"],
            ["tracked_days", "\(summary.trackedDays)"],
            ["review_days", "\(summary.reviewDays)"],
            ["average_net_worked_minutes", "\(summary.averageNetWorkedMinutes)"],
            [],
            ["date", "sessions", "net_worked_minutes", "target_minutes", "balance_minutes", "review_issue", "note"]
        ] + summary.rows.map { row in
            [
                row.date.id,
                "\(row.sessions)",
                "\(row.netWorkedMinutes)",
                "\(row.targetMinutes)",
                "\(row.balanceMinutes)",
                row.reviewIssue?.rawValue ?? "",
                row.note ?? ""
            ]
        }

        return Data(rows.map(csvLine).joined(separator: "\n").utf8)
    }

    func pdfData(summary: AnalyticsReportSummary) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPDFPage(nil)
        drawText("LoqClock Analytics Report", at: CGPoint(x: 56, y: 720), size: 22, weight: .semibold)
        drawText("Timeframe: \(summary.timeframe.rawValue)", at: CGPoint(x: 56, y: 688), size: 12, weight: .regular)
        drawText("Total balance: \(summary.totalBalanceMinutes) min", at: CGPoint(x: 56, y: 656), size: 12, weight: .regular)
        drawText("Tracked days: \(summary.trackedDays)", at: CGPoint(x: 56, y: 634), size: 12, weight: .regular)
        drawText("Review days: \(summary.reviewDays)", at: CGPoint(x: 56, y: 612), size: 12, weight: .regular)
        drawText("Average net worked: \(summary.averageNetWorkedMinutes) min", at: CGPoint(x: 56, y: 590), size: 12, weight: .regular)

        var y = 548
        drawText("Recent Rows", at: CGPoint(x: 56, y: y), size: 14, weight: .semibold)
        y -= 26

        for row in summary.rows.suffix(16) {
            let reviewText = row.reviewIssue?.rawValue ?? "ok"
            drawText(
                "\(row.date.id) | sessions \(row.sessions) | net \(row.netWorkedMinutes)m | balance \(row.balanceMinutes)m | \(reviewText)",
                at: CGPoint(x: 56, y: y),
                size: 10,
                weight: .regular
            )
            y -= 18
        }

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func isEntry(_ entry: WorkDayEntry, in timeframe: AnalyticsTimeframe, relativeTo referenceDate: Date) -> Bool {
        guard let date = entry.date.date(in: calendar) else {
            return false
        }

        switch timeframe {
        case .week:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .month)
        case .year:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .year)
        case .all:
            return true
        }
    }

    private func dayCount(for timeframe: AnalyticsTimeframe, relativeTo referenceDate: Date, fallback: Int) -> Int {
        switch timeframe {
        case .week:
            return calendar.range(of: .weekday, in: .weekOfYear, for: referenceDate)?.count ?? 7
        case .month:
            return calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? max(1, fallback)
        case .year:
            return calendar.range(of: .day, in: .year, for: referenceDate)?.count ?? 365
        case .all:
            return max(1, fallback)
        }
    }

    private func csvLine(_ fields: [String]) -> String {
        fields
            .map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            .joined(separator: ",")
    }

    private func drawText(
        _ string: String,
        at point: CGPoint,
        size: CGFloat,
        weight: NSFont.Weight
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.labelColor
        ]
        string.draw(at: point, withAttributes: attributes)
    }
}
