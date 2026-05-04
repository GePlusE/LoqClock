import Foundation
import Testing
@testable import LoqClock

struct WorkDayEntryValidatorTests {
    private let validator = WorkDayEntryValidator(calendar: validationCalendar)
    private let now = validationDate(2026, 5, 20, 12, 0)

    @Test
    func rejectsFutureDates() {
        let error = validator.validate(
            day: LocalDay(year: 2026, month: 5, day: 21),
            startTime: nil,
            endTime: nil,
            lunchDurationMinutes: 60,
            additionalBreaks: [],
            existingDates: [],
            originalDate: nil,
            now: now
        )

        #expect(error == .futureDateNotAllowed)
    }

    @Test
    func rejectsPastDaysWithoutBothTimes() {
        let error = validator.validate(
            day: LocalDay(year: 2026, month: 5, day: 19),
            startTime: validationDate(2026, 5, 19, 9, 0),
            endTime: nil,
            lunchDurationMinutes: 60,
            additionalBreaks: [],
            existingDates: [],
            originalDate: nil,
            now: now
        )

        #expect(error == .startAndEndRequiredForPastDay)
    }

    @Test
    func rejectsEndBeforeStart() {
        let error = validator.validate(
            day: LocalDay(year: 2026, month: 5, day: 20),
            startTime: validationDate(2026, 5, 20, 17, 0),
            endTime: validationDate(2026, 5, 20, 9, 0),
            lunchDurationMinutes: 60,
            additionalBreaks: [],
            existingDates: [],
            originalDate: nil,
            now: now
        )

        #expect(error == .endBeforeStart)
    }

    @Test
    func rejectsDuplicateDatesWhenChangingDay() {
        let error = validator.validate(
            day: LocalDay(year: 2026, month: 5, day: 19),
            startTime: validationDate(2026, 5, 19, 9, 0),
            endTime: validationDate(2026, 5, 19, 17, 0),
            lunchDurationMinutes: 60,
            additionalBreaks: [],
            existingDates: [LocalDay(year: 2026, month: 5, day: 19)],
            originalDate: LocalDay(year: 2026, month: 5, day: 18),
            now: now
        )

        #expect(error == .duplicateDate)
    }
}

private func validationDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let components = DateComponents(
        calendar: validationCalendar,
        timeZone: TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return components.date!
}

private let validationCalendar = Calendar(identifier: .gregorian)
