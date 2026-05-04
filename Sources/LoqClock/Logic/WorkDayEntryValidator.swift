import Foundation

enum WorkDayEntryValidationError: LocalizedError, Equatable {
    case futureDateNotAllowed
    case duplicateDate
    case startAndEndRequiredForPastDay
    case endBeforeStart
    case lunchExceedsGrossWork
    case breaksExceedGrossWork

    var errorDescription: String? {
        switch self {
        case .futureDateNotAllowed:
            return "Future dates are not supported."
        case .duplicateDate:
            return "An entry already exists for the selected date."
        case .startAndEndRequiredForPastDay:
            return "Past days require both a start time and an end time."
        case .endBeforeStart:
            return "End time must not be earlier than start time."
        case .lunchExceedsGrossWork:
            return "Lunch duration must not exceed gross worked time."
        case .breaksExceedGrossWork:
            return "Additional breaks must not exceed the remaining gross worked time."
        }
    }
}

struct WorkDayEntryValidator {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func validate(
        day: LocalDay,
        startTime: Date?,
        endTime: Date?,
        lunchDurationMinutes: Int,
        additionalBreaks: [WorkBreak],
        existingDates: Set<LocalDay>,
        originalDate: LocalDay?,
        now: Date = .now
    ) -> WorkDayEntryValidationError? {
        let today = LocalDay(date: now, calendar: calendar)

        if day > today {
            return .futureDateNotAllowed
        }

        if let originalDate {
            if day != originalDate && existingDates.contains(day) {
                return .duplicateDate
            }
        } else if existingDates.contains(day) {
            return .duplicateDate
        }

        if day < today && (startTime == nil || endTime == nil) {
            return .startAndEndRequiredForPastDay
        }

        if let startTime, let endTime {
            let grossMinutes = Int(endTime.timeIntervalSince(startTime) / 60)
            if grossMinutes < 0 {
                return .endBeforeStart
            }

            if lunchDurationMinutes > grossMinutes {
                return .lunchExceedsGrossWork
            }

            let breakMinutes = additionalBreaks.reduce(0) { $0 + $1.durationMinutes }
            if lunchDurationMinutes + breakMinutes > grossMinutes {
                return .breaksExceedGrossWork
            }
        }

        return nil
    }
}
