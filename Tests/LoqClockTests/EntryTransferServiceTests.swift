import Foundation
import Testing
@testable import LoqClock

struct EntryTransferServiceTests {
    private let service = EntryTransferService()

    @Test
    func jsonRoundTripPreservesSettingsEntriesAndSessions() throws {
        let day = LocalDay(year: 2026, month: 5, day: 10)
        let state = AppState(
            settings: AppSettings(
                defaultTargetWorkDurationMinutes: 360,
                defaultLunchDurationMinutes: 30
            ),
            entries: [
                WorkDayEntry(
                    date: day,
                    targetWorkDurationMinutes: 420,
                    lunchDurationMinutes: 30,
                    additionalBreaks: [WorkBreak(name: "Coffee", durationMinutes: 10)],
                    notes: "Focus day",
                    sessions: [
                        WorkSession(
                            assignedWorkDayDate: day,
                            startTimestamp: transferDate(2026, 5, 10, 9, 0),
                            endTimestamp: transferDate(2026, 5, 10, 17, 30)
                        )
                    ]
                )
            ]
        )

        let data = try service.exportData(state: state, format: .json)
        let imported = try service.importData(data, format: .json)

        #expect(imported.settings == state.settings)
        #expect(imported.entries.count == 1)
        #expect(imported.entries.first?.notes == "Focus day")
        #expect(imported.entries.first?.additionalBreaks.isEmpty == true)
        #expect(imported.entries.first?.sessions.count == 1)
        #expect(imported.entries.first?.sessions.first?.startTimestamp == transferDate(2026, 5, 10, 9, 0))
    }

    @Test
    func csvRoundTripPreservesSessionRows() throws {
        let day = LocalDay(year: 2026, month: 5, day: 11)
        let state = AppState(
            entries: [
                WorkDayEntry(
                    date: day,
                    timezoneIdentifier: "UTC",
                    targetWorkDurationMinutes: 450,
                    lunchDurationMinutes: 45,
                    notes: "CSV test",
                    sessions: [
                        WorkSession(
                            assignedWorkDayDate: day,
                            startTimestamp: transferDate(2026, 5, 11, 8, 30),
                            endTimestamp: transferDate(2026, 5, 11, 12, 0)
                        ),
                        WorkSession(
                            assignedWorkDayDate: day,
                            startTimestamp: transferDate(2026, 5, 11, 13, 0),
                            endTimestamp: transferDate(2026, 5, 11, 17, 15)
                        )
                    ]
                )
            ]
        )

        let data = try service.exportData(state: state, format: .csv)
        let imported = try service.importData(data, format: .csv)

        #expect(imported.settings == nil)
        #expect(imported.entries.count == 1)
        #expect(imported.entries.first?.date.id == "2026-05-11")
        #expect(imported.entries.first?.timezoneIdentifier == "UTC")
        #expect(imported.entries.first?.targetWorkDurationMinutes == 450)
        #expect(imported.entries.first?.lunchDurationMinutes == 45)
        #expect(imported.entries.first?.notes == "CSV test")
        #expect(imported.entries.first?.sessions.count == 2)
        #expect(imported.entries.first?.sessions.map(\.startTimestamp) == [
            transferDate(2026, 5, 11, 8, 30),
            transferDate(2026, 5, 11, 13, 0)
        ])
    }

    @Test
    func csvImportAllowsMultipleSessionRowsForOneDate() throws {
        let csv = """
        "date","timezone_identifier","target_work_duration_minutes","planned_break_duration_minutes","note","session_id","session_start_timestamp","session_end_timestamp"
        "2026-05-12","UTC","480","60","","","2026-05-12T08:00:00Z","2026-05-12T12:00:00Z"
        "2026-05-12","UTC","480","60","","","2026-05-12T13:00:00Z","2026-05-12T17:00:00Z"
        """

        let imported = try service.importData(Data(csv.utf8), format: .csv)

        #expect(imported.entries.count == 1)
        #expect(imported.entries.first?.sessions.count == 2)
    }

    @Test
    func legacyCsvStillRejectsDuplicateDatesInsideFile() throws {
        let csv = """
        "date","start_time","end_time","target_work_duration_minutes","lunch_duration_minutes","additional_breaks_json","notes"
        "2026-05-12","","","480","60","[]",""
        "2026-05-12","","","480","60","[]",""
        """

        #expect(throws: EntryTransferError.self) {
            _ = try service.importData(Data(csv.utf8), format: .csv)
        }
    }
}

private func transferDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    let components = DateComponents(
        calendar: transferCalendar,
        timeZone: TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return components.date!
}

private let transferCalendar = Calendar(identifier: .gregorian)
