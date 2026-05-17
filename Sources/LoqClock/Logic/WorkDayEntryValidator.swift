import Foundation

enum WorkDayReviewIssue: String, Codable, Equatable, Sendable {
    case missingEndTime = "missing_end_time"
    case timeChangeBoundary = "time_change_boundary"
    case exceedsOvernightLimit = "exceeds_overnight_limit"
    case overlap
    case invalidDuration = "invalid_duration"
    case missingRequiredFields = "missing_required_fields"

    var priority: Int {
        switch self {
        case .missingEndTime:
            return 0
        case .timeChangeBoundary:
            return 1
        case .exceedsOvernightLimit:
            return 2
        case .overlap:
            return 3
        case .invalidDuration:
            return 4
        case .missingRequiredFields:
            return 5
        }
    }
}

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

    func reviewIssues(for entry: WorkDayEntry, now: Date = .now) -> [WorkDayReviewIssue] {
        var issues = Set<WorkDayReviewIssue>()

        if entry.targetWorkDurationMinutes < 0 || entry.plannedBreakDurationMinutes < 0 {
            issues.insert(.missingRequiredFields)
        }

        let sortedSessions = entry.sessions.sorted { $0.startTimestamp < $1.startTimestamp }

        for session in sortedSessions {
            if session.assignedWorkDayDate != entry.date {
                issues.insert(.missingRequiredFields)
            }

            guard let endTimestamp = session.endTimestamp else {
                issues.insert(.missingEndTime)
                continue
            }

            let normalizedStart = TimeNormalizer.roundedDownToMinute(session.startTimestamp)
            let normalizedEnd = TimeNormalizer.roundedUpToMinuteIfNeeded(endTimestamp)
            let durationMinutes = Int(normalizedEnd.timeIntervalSince(normalizedStart) / 60)

            if durationMinutes < 1 {
                issues.insert(.invalidDuration)
            }

            if crossesTimeChangeBoundary(start: normalizedStart, end: normalizedEnd, timezoneIdentifier: entry.timezoneIdentifier) {
                issues.insert(.timeChangeBoundary)
            }

            if exceedsAllowedOvernightLimit(
                start: normalizedStart,
                end: normalizedEnd,
                assignedDay: entry.date,
                timezoneIdentifier: entry.timezoneIdentifier
            ) {
                issues.insert(.exceedsOvernightLimit)
            }
        }

        for pair in zip(sortedSessions, sortedSessions.dropFirst()) {
            guard let previousEnd = pair.0.endTimestamp else {
                continue
            }

            let previousEndRounded = TimeNormalizer.roundedUpToMinuteIfNeeded(previousEnd)
            let nextStartRounded = TimeNormalizer.roundedDownToMinute(pair.1.startTimestamp)

            if previousEndRounded > nextStartRounded {
                issues.insert(.overlap)
            }
        }

        return issues.sorted { lhs, rhs in
            lhs.priority < rhs.priority
        }
    }

    func primaryReviewIssue(for entry: WorkDayEntry, now: Date = .now) -> WorkDayReviewIssue? {
        reviewIssues(for: entry, now: now).first
    }

    func requiresReview(_ entry: WorkDayEntry, now: Date = .now) -> Bool {
        primaryReviewIssue(for: entry, now: now) != nil
    }

    private func exceedsAllowedOvernightLimit(
        start: Date,
        end: Date,
        assignedDay: LocalDay,
        timezoneIdentifier: String
    ) -> Bool {
        var workdayCalendar = calendar
        workdayCalendar.timeZone = TimeZone(identifier: timezoneIdentifier) ?? calendar.timeZone

        let startDay = LocalDay(date: start, calendar: workdayCalendar)
        let endDay = LocalDay(date: end, calendar: workdayCalendar)

        guard startDay == assignedDay || startDay < assignedDay else {
            return true
        }

        guard let assignedDate = assignedDay.date(in: workdayCalendar),
              let latestAllowedDate = workdayCalendar.date(byAdding: .day, value: 1, to: assignedDate) else {
            return true
        }

        let latestAllowedDay = LocalDay(date: latestAllowedDate, calendar: workdayCalendar)
        return endDay > latestAllowedDay
    }

    private func crossesTimeChangeBoundary(
        start: Date,
        end: Date,
        timezoneIdentifier: String
    ) -> Bool {
        let timeZone = TimeZone(identifier: timezoneIdentifier) ?? calendar.timeZone
        return timeZone.secondsFromGMT(for: start) != timeZone.secondsFromGMT(for: end)
    }
}
