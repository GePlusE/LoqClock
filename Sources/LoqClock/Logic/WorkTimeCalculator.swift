import Foundation

struct WorkTimeCalculator {
    let calendar: Calendar
    private let validator: WorkDayEntryValidator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.validator = WorkDayEntryValidator(calendar: calendar)
    }

    func netWorkedMinutes(
        for entry: WorkDayEntry,
        now: Date = .now,
        liveBreakDeductionThresholdMinutes: Int = AppSettings.default.liveBreakDeductionThresholdMinutes
    ) -> Int {
        guard !entry.sessions.isEmpty else {
            return 0
        }

        let grossMinutes = grossWorkedMinutes(for: entry, now: now)

        guard entry.sessions.count == 1 else {
            return grossMinutes
        }

        return max(
            0,
            grossMinutes - totalBreakMinutes(
                for: entry,
                now: now,
                liveBreakDeductionThresholdMinutes: liveBreakDeductionThresholdMinutes
            )
        )
    }

    func dailyBalanceMinutes(for entry: WorkDayEntry, now: Date = .now) -> Int {
        guard !entry.sessions.isEmpty else {
            return 0
        }

        return netWorkedMinutes(for: entry, now: now) - entry.targetWorkDurationMinutes
    }

    func totalBalanceMinutes(for entries: [WorkDayEntry], now: Date = .now) -> Int {
        entries.reduce(0) { partialResult, entry in
            partialResult + balanceContributionMinutes(for: entry, now: now)
        }
    }

    func weekBalanceMinutes(for entries: [WorkDayEntry], relativeTo referenceDate: Date, now: Date = .now) -> Int {
        totalBalanceMinutes(
            for: filteredEntries(inSameWeekAs: referenceDate, from: entries),
            now: now
        )
    }

    func monthBalanceMinutes(for entries: [WorkDayEntry], relativeTo referenceDate: Date, now: Date = .now) -> Int {
        totalBalanceMinutes(
            for: filteredEntries(inSameMonthAs: referenceDate, from: entries),
            now: now
        )
    }

    func yearBalanceMinutes(for entries: [WorkDayEntry], relativeTo referenceDate: Date, now: Date = .now) -> Int {
        totalBalanceMinutes(
            for: filteredEntries(inSameYearAs: referenceDate, from: entries),
            now: now
        )
    }

    func leaveTimeForZeroToday(
        for entry: WorkDayEntry,
        now: Date = .now,
        liveBreakDeductionThresholdMinutes: Int = AppSettings.default.liveBreakDeductionThresholdMinutes
    ) -> Date? {
        guard entry.activeSession != nil else {
            return nil
        }

        return leaveTime(
            forRequiredNetMinutes: entry.targetWorkDurationMinutes,
            entry: entry,
            now: now,
            liveBreakDeductionThresholdMinutes: liveBreakDeductionThresholdMinutes
        )
    }

    func leaveTimeForZeroWeek(
        todayEntry: WorkDayEntry,
        allEntries: [WorkDayEntry],
        now: Date = .now,
        liveBreakDeductionThresholdMinutes: Int = AppSettings.default.liveBreakDeductionThresholdMinutes
    ) -> Date? {
        guard todayEntry.activeSession != nil,
              let todayDate = todayEntry.date.date(in: calendar) else {
            return nil
        }

        let weekBalanceBeforeToday = filteredEntries(inSameWeekAs: todayDate, from: allEntries)
            .filter { $0.date < todayEntry.date }
            .reduce(0) { partialResult, entry in
                partialResult + balanceContributionMinutes(for: entry, now: now)
            }

        let requiredNetWorkToday = todayEntry.targetWorkDurationMinutes - weekBalanceBeforeToday
        return leaveTime(
            forRequiredNetMinutes: requiredNetWorkToday,
            entry: todayEntry,
            now: now,
            liveBreakDeductionThresholdMinutes: liveBreakDeductionThresholdMinutes
        )
    }

    func totalBreakMinutes(
        for entry: WorkDayEntry,
        now: Date = .now,
        liveBreakDeductionThresholdMinutes: Int = AppSettings.default.liveBreakDeductionThresholdMinutes
    ) -> Int {
        let sortedSessions = entry.sessions.sorted { $0.startTimestamp < $1.startTimestamp }

        guard sortedSessions.count > 1 else {
            let grossMinutes = grossWorkedMinutes(for: entry, now: now)
            let plannedBreakMinutes = entry.lunchDurationMinutes + entry.additionalBreaks.reduce(0) { $0 + $1.durationMinutes }

            if entry.activeSession != nil && grossMinutes <= liveBreakDeductionThresholdMinutes {
                return 0
            }

            return min(grossMinutes, plannedBreakMinutes)
        }

        return zip(sortedSessions, sortedSessions.dropFirst()).reduce(0) { partialResult, pair in
            guard let previousEnd = pair.0.endTimestamp else {
                return partialResult
            }

            let previousEndRounded = TimeNormalizer.roundedUpToMinuteIfNeeded(previousEnd)
            let nextStartRounded = TimeNormalizer.roundedDownToMinute(pair.1.startTimestamp)
            let gapMinutes = max(0, Int(nextStartRounded.timeIntervalSince(previousEndRounded) / 60))
            return partialResult + gapMinutes
        }
    }

    func grossWorkedMinutes(for entry: WorkDayEntry, now: Date = .now) -> Int {
        entry.sessions.reduce(0) { partialResult, session in
            partialResult + sessionDurationMinutes(for: session, now: now)
        }
    }

    func sessionDurationMinutes(for session: WorkSession, now: Date = .now) -> Int {
        let normalizedStart = TimeNormalizer.roundedDownToMinute(session.startTimestamp)
        let normalizedEnd: Date

        if let endTimestamp = session.endTimestamp {
            normalizedEnd = TimeNormalizer.roundedUpToMinuteIfNeeded(endTimestamp)
        } else {
            normalizedEnd = TimeNormalizer.roundedDownToMinute(now)
        }

        return max(0, Int(normalizedEnd.timeIntervalSince(normalizedStart) / 60))
    }

    private func balanceContributionMinutes(for entry: WorkDayEntry, now: Date) -> Int {
        guard !entry.sessions.isEmpty,
              !validator.requiresReview(entry, now: now) else {
            return 0
        }

        return dailyBalanceMinutes(for: entry, now: now)
    }

    private func leaveTime(
        forRequiredNetMinutes requiredNetMinutes: Int,
        entry: WorkDayEntry,
        now: Date,
        liveBreakDeductionThresholdMinutes: Int
    ) -> Date? {
        guard let activeSession = entry.activeSession else {
            return nil
        }

        if requiredNetMinutes <= 0 {
            return TimeNormalizer.roundedUpToMinuteIfNeeded(now)
        }

        if entry.sessions.count == 1 {
            let breakMinutes = entry.lunchDurationMinutes + entry.additionalBreaks.reduce(0) { $0 + $1.durationMinutes }
            let grossNeeded: Int

            if requiredNetMinutes <= liveBreakDeductionThresholdMinutes {
                grossNeeded = requiredNetMinutes
            } else {
                grossNeeded = requiredNetMinutes + breakMinutes
            }

            return TimeNormalizer.roundedDownToMinute(activeSession.startTimestamp)
                .addingTimeInterval(TimeInterval(grossNeeded * 60))
        }

        let currentNet = netWorkedMinutes(
            for: entry,
            now: now,
            liveBreakDeductionThresholdMinutes: liveBreakDeductionThresholdMinutes
        )
        let remainingMinutes = max(0, requiredNetMinutes - currentNet)

        return TimeNormalizer.roundedUpToMinuteIfNeeded(now)
            .addingTimeInterval(TimeInterval(remainingMinutes * 60))
    }

    private func filteredEntries(inSameWeekAs referenceDate: Date, from entries: [WorkDayEntry]) -> [WorkDayEntry] {
        entries.filter { entry in
            guard let date = entry.date.date(in: calendar) else { return false }
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear)
        }
    }

    private func filteredEntries(inSameMonthAs referenceDate: Date, from entries: [WorkDayEntry]) -> [WorkDayEntry] {
        entries.filter { entry in
            guard let date = entry.date.date(in: calendar) else { return false }
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .month)
        }
    }

    private func filteredEntries(inSameYearAs referenceDate: Date, from entries: [WorkDayEntry]) -> [WorkDayEntry] {
        entries.filter { entry in
            guard let date = entry.date.date(in: calendar) else { return false }
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .year)
        }
    }
}
