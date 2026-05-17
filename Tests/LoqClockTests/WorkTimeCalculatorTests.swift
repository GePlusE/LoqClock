import Foundation
import Testing
@testable import LoqClock

struct WorkTimeCalculatorTests {
    private let calculator = WorkTimeCalculator(calendar: testCalendar)

    @Test
    func completedDayCalculatesNetWorkAndBalance() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 4),
            startTime: date(2026, 5, 4, 9, 0),
            endTime: date(2026, 5, 4, 18, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        #expect(calculator.netWorkedMinutes(for: entry) == 480)
        #expect(calculator.dailyBalanceMinutes(for: entry) == 0)
    }

    @Test
    func negativeNetWorkClampsToZero() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 4),
            startTime: date(2026, 5, 4, 9, 0),
            endTime: date(2026, 5, 4, 9, 20),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        #expect(calculator.netWorkedMinutes(for: entry) == 0)
        #expect(calculator.dailyBalanceMinutes(for: entry) == -480)
    }

    @Test
    func halfDayOverrideBalancesCorrectly() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 8, 0),
            endTime: date(2026, 5, 5, 12, 0),
            targetWorkDurationMinutes: 240,
            lunchDurationMinutes: 0
        )

        #expect(calculator.netWorkedMinutes(for: entry) == 240)
        #expect(calculator.dailyBalanceMinutes(for: entry) == 0)
    }

    @Test
    func additionalBreaksReduceNetWorkedTime() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: date(2026, 5, 5, 18, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 30,
            additionalBreaks: [WorkBreak(name: "Coffee", durationMinutes: 15)]
        )

        #expect(calculator.totalBreakMinutes(for: entry) == 45)
        #expect(calculator.netWorkedMinutes(for: entry) == 495)
        #expect(calculator.dailyBalanceMinutes(for: entry) == 15)
    }

    @Test
    func activeSingleSessionDoesNotDeductBreakBeforeThreshold() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        #expect(calculator.netWorkedMinutes(for: entry, now: date(2026, 5, 5, 14, 0)) == 300)
        #expect(calculator.totalBreakMinutes(for: entry, now: date(2026, 5, 5, 14, 0)) == 0)
    }

    @Test
    func activeSingleSessionDeductsBreakAfterThreshold() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        #expect(calculator.netWorkedMinutes(for: entry, now: date(2026, 5, 5, 16, 0)) == 360)
        #expect(calculator.totalBreakMinutes(for: entry, now: date(2026, 5, 5, 16, 0)) == 60)
    }

    @Test
    func multiSessionDaysSumSessionsAndDisplayGapsAsBreaks() {
        let day = LocalDay(year: 2026, month: 5, day: 5)
        let entry = WorkDayEntry(
            date: day,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60,
            sessions: [
                WorkSession(
                    assignedWorkDayDate: day,
                    startTimestamp: date(2026, 5, 5, 9, 0),
                    endTimestamp: date(2026, 5, 5, 12, 0)
                ),
                WorkSession(
                    assignedWorkDayDate: day,
                    startTimestamp: date(2026, 5, 5, 13, 15),
                    endTimestamp: date(2026, 5, 5, 18, 0)
                )
            ]
        )

        #expect(calculator.netWorkedMinutes(for: entry) == 465)
        #expect(calculator.totalBreakMinutes(for: entry) == 75)
        #expect(calculator.dailyBalanceMinutes(for: entry) == -15)
    }

    @Test
    func emptyEntriesDoNotCreateExpectedHours() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60,
            notes: "Doctor appointment"
        )

        #expect(calculator.netWorkedMinutes(for: entry) == 0)
        #expect(calculator.dailyBalanceMinutes(for: entry) == 0)
        #expect(calculator.totalBalanceMinutes(for: [entry]) == 0)
    }

    @Test
    func reviewRequiredEntriesAreExcludedFromPeriodBalances() {
        let incomplete = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )
        let completed = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 6),
            startTime: date(2026, 5, 6, 9, 0),
            endTime: date(2026, 5, 6, 18, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        #expect(calculator.dailyBalanceMinutes(for: incomplete, now: date(2026, 5, 5, 12, 0)) == -300)
        #expect(calculator.totalBalanceMinutes(for: [incomplete, completed], now: date(2026, 5, 6, 18, 0)) == 0)
    }

    @Test
    func periodBalancesUseOnlyTrackedDays() {
        let entries = [
            WorkDayEntry(
                date: LocalDay(year: 2026, month: 5, day: 4),
                startTime: date(2026, 5, 4, 9, 0),
                endTime: date(2026, 5, 4, 19, 0),
                targetWorkDurationMinutes: 480,
                lunchDurationMinutes: 60
            ),
            WorkDayEntry(
                date: LocalDay(year: 2026, month: 5, day: 5),
                startTime: date(2026, 5, 5, 9, 0),
                endTime: date(2026, 5, 5, 17, 0),
                targetWorkDurationMinutes: 480,
                lunchDurationMinutes: 60
            ),
            WorkDayEntry(
                date: LocalDay(year: 2026, month: 4, day: 30),
                startTime: date(2026, 4, 30, 9, 0),
                endTime: date(2026, 4, 30, 18, 0),
                targetWorkDurationMinutes: 480,
                lunchDurationMinutes: 60
            ),
            WorkDayEntry(
                date: LocalDay(year: 2025, month: 12, day: 31),
                startTime: date(2025, 12, 31, 9, 0),
                endTime: date(2025, 12, 31, 20, 0),
                targetWorkDurationMinutes: 480,
                lunchDurationMinutes: 60
            )
        ]

        let reference = date(2026, 5, 5, 12, 0)

        #expect(calculator.totalBalanceMinutes(for: entries) == 120)
        #expect(calculator.weekBalanceMinutes(for: entries, relativeTo: reference) == 0)
        #expect(calculator.monthBalanceMinutes(for: entries, relativeTo: reference) == 0)
        #expect(calculator.yearBalanceMinutes(for: entries, relativeTo: reference) == 0)
    }

    @Test
    func leaveTimeForZeroTodayUsesStartLunchAndTarget() {
        let entry = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 6),
            startTime: date(2026, 5, 6, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60,
            additionalBreaks: [WorkBreak(name: "Walk", durationMinutes: 15)]
        )

        #expect(calculator.leaveTimeForZeroToday(for: entry) == date(2026, 5, 6, 18, 15))
    }

    @Test
    func weeklyLeavePredictionUsesBalanceBeforeTodayWithoutDoubleCountingToday() {
        let monday = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 4),
            startTime: date(2026, 5, 4, 9, 0),
            endTime: date(2026, 5, 4, 19, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )
        let tuesday = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: date(2026, 5, 5, 17, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )
        let today = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 6),
            startTime: date(2026, 5, 6, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        let leaveTime = calculator.leaveTimeForZeroWeek(
            todayEntry: today,
            allEntries: [monday, tuesday, today]
        )

        #expect(leaveTime == date(2026, 5, 6, 18, 0))
    }

    @Test
    func weeklyLeavePredictionMovesEarlierWhenWeekAlreadyHasPositiveBalance() {
        let monday = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 4),
            startTime: date(2026, 5, 4, 9, 0),
            endTime: date(2026, 5, 4, 21, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )
        let today = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        let leaveTime = calculator.leaveTimeForZeroWeek(
            todayEntry: today,
            allEntries: [monday, today]
        )

        #expect(leaveTime == date(2026, 5, 5, 14, 0))
    }

    @Test
    func weeklyLeavePredictionMovesLaterWhenWeekHasNegativeBalance() {
        let monday = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 4),
            startTime: date(2026, 5, 4, 9, 0),
            endTime: date(2026, 5, 4, 15, 0),
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )
        let today = WorkDayEntry(
            date: LocalDay(year: 2026, month: 5, day: 5),
            startTime: date(2026, 5, 5, 9, 0),
            endTime: nil,
            targetWorkDurationMinutes: 480,
            lunchDurationMinutes: 60
        )

        let leaveTime = calculator.leaveTimeForZeroWeek(
            todayEntry: today,
            allEntries: [monday, today]
        )

        #expect(leaveTime == date(2026, 5, 5, 21, 0))
    }

    @Test
    func sessionDurationsNormalizeStartDownAndStopUp() {
        let day = LocalDay(year: 2026, month: 5, day: 5)
        let session = WorkSession(
            assignedWorkDayDate: day,
            startTimestamp: Date(timeIntervalSince1970: 1_777_705_230),
            endTimestamp: Date(timeIntervalSince1970: 1_777_705_291)
        )

        #expect(calculator.sessionDurationMinutes(for: session) == 2)
    }
}

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let components = DateComponents(
        calendar: testCalendar,
        timeZone: TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return components.date!
}

private let testCalendar = Calendar(identifier: .gregorian)
