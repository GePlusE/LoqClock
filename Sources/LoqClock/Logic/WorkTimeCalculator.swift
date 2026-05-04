import Foundation

struct WorkTimeCalculator {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func netWorkedMinutes(for entry: WorkDayEntry, now: Date = .now) -> Int {
        guard let startTime = entry.startTime else {
            return 0
        }

        let effectiveEndTime = entry.endTime ?? now
        let grossMinutes = max(0, Int(effectiveEndTime.timeIntervalSince(startTime) / 60))
        return max(0, grossMinutes - totalBreakMinutes(for: entry))
    }

    func dailyBalanceMinutes(for entry: WorkDayEntry, now: Date = .now) -> Int {
        netWorkedMinutes(for: entry, now: now) - entry.targetWorkDurationMinutes
    }

    func totalBalanceMinutes(for entries: [WorkDayEntry], now: Date = .now) -> Int {
        entries.reduce(0) { partialResult, entry in
            partialResult + dailyBalanceMinutes(for: entry, now: now)
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

    func leaveTimeForZeroToday(for entry: WorkDayEntry) -> Date? {
        guard let startTime = entry.startTime else {
            return nil
        }

        let totalMinutes = entry.targetWorkDurationMinutes + totalBreakMinutes(for: entry)
        return startTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    func leaveTimeForZeroWeek(
        todayEntry: WorkDayEntry,
        allEntries: [WorkDayEntry]
    ) -> Date? {
        guard let startTime = todayEntry.startTime,
              let todayDate = todayEntry.date.date(in: calendar) else {
            return nil
        }

        let weekBalanceBeforeToday = filteredEntries(inSameWeekAs: todayDate, from: allEntries)
            .filter { $0.date < todayEntry.date }
            .reduce(0) { partialResult, entry in
                partialResult + dailyBalanceMinutes(for: entry)
            }

        let requiredNetWorkToday = todayEntry.targetWorkDurationMinutes - weekBalanceBeforeToday
        let totalMinutes = totalBreakMinutes(for: todayEntry) + requiredNetWorkToday
        return startTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    func totalBreakMinutes(for entry: WorkDayEntry) -> Int {
        entry.lunchDurationMinutes + entry.additionalBreaks.reduce(0) { $0 + $1.durationMinutes }
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
