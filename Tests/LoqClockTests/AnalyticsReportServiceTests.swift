import Foundation
import Testing
@testable import LoqClock

struct AnalyticsReportServiceTests {
    private let service = AnalyticsReportService(calendar: analyticsCalendar)

    @Test
    func summaryExcludesReviewDaysFromBalances() {
        let validDay = LocalDay(year: 2026, month: 5, day: 4)
        let reviewDay = LocalDay(year: 2026, month: 5, day: 5)
        let summary = service.summary(
            entries: [
                WorkDayEntry(
                    date: validDay,
                    startTime: analyticsDate(2026, 5, 4, 9, 0),
                    endTime: analyticsDate(2026, 5, 4, 18, 0),
                    targetWorkDurationMinutes: 480,
                    lunchDurationMinutes: 60
                ),
                WorkDayEntry(
                    date: reviewDay,
                    startTime: analyticsDate(2026, 5, 5, 9, 0),
                    endTime: nil,
                    targetWorkDurationMinutes: 480,
                    lunchDurationMinutes: 60
                )
            ],
            timeframe: .week,
            includeMissingDaysInAverages: false,
            relativeTo: analyticsDate(2026, 5, 6, 12, 0),
            now: analyticsDate(2026, 5, 6, 12, 0)
        )

        #expect(summary.totalBalanceMinutes == 0)
        #expect(summary.trackedDays == 1)
        #expect(summary.reviewDays == 1)
        #expect(summary.rows.first(where: { $0.date == reviewDay })?.reviewIssue == .missingEndTime)
    }

    @Test
    func csvDataIncludesDailyRows() {
        let day = LocalDay(year: 2026, month: 5, day: 4)
        let summary = service.summary(
            entries: [
                WorkDayEntry(
                    date: day,
                    startTime: analyticsDate(2026, 5, 4, 9, 0),
                    endTime: analyticsDate(2026, 5, 4, 18, 0),
                    targetWorkDurationMinutes: 480,
                    lunchDurationMinutes: 60,
                    notes: "Report day"
                )
            ],
            timeframe: .month,
            includeMissingDaysInAverages: false,
            relativeTo: analyticsDate(2026, 5, 6, 12, 0)
        )

        let csv = String(decoding: service.csvData(summary: summary), as: UTF8.self)

        #expect(csv.contains("\"date\",\"sessions\",\"net_worked_minutes\""))
        #expect(csv.contains("\"2026-05-04\",\"1\",\"480\",\"480\",\"0\",\"\",\"Report day\""))
    }

    @Test
    func pdfDataCreatesPdfPayload() {
        let summary = AnalyticsReportSummary(
            timeframe: .all,
            totalBalanceMinutes: 0,
            trackedDays: 0,
            reviewDays: 0,
            averageNetWorkedMinutes: 0,
            rows: []
        )

        let data = service.pdfData(summary: summary)

        #expect(data.starts(with: Data("%PDF".utf8)))
    }
}

private func analyticsDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let components = DateComponents(
        calendar: analyticsCalendar,
        timeZone: TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return components.date!
}

private let analyticsCalendar = Calendar(identifier: .gregorian)
