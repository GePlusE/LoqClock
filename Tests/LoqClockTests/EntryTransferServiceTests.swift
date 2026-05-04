import Foundation
import Testing
@testable import LoqClock

struct EntryTransferServiceTests {
    private let service = EntryTransferService()

    @Test
    func jsonRoundTripPreservesSettingsEntriesAndBreaks() throws {
        let state = AppState(
            settings: AppSettings(
                defaultTargetWorkDurationMinutes: 360,
                defaultLunchDurationMinutes: 30
            ),
            entries: [
                WorkDayEntry(
                    date: LocalDay(year: 2026, month: 5, day: 10),
                    startTime: transferDate(2026, 5, 10, 9, 0),
                    endTime: transferDate(2026, 5, 10, 17, 30),
                    targetWorkDurationMinutes: 420,
                    lunchDurationMinutes: 30,
                    additionalBreaks: [WorkBreak(name: "Coffee", durationMinutes: 10)],
                    notes: "Focus day"
                )
            ]
        )

        let data = try service.exportData(state: state, format: .json)
        let imported = try service.importData(data, format: .json)

        #expect(imported.settings == state.settings)
        #expect(imported.entries.count == 1)
        #expect(imported.entries.first?.notes == "Focus day")
        #expect(imported.entries.first?.additionalBreaks.map(\.name) == ["Coffee"])
        #expect(imported.entries.first?.additionalBreaks.map(\.durationMinutes) == [10])
    }

    @Test
    func csvRoundTripPreservesEntryFields() throws {
        let state = AppState(
            entries: [
                WorkDayEntry(
                    date: LocalDay(year: 2026, month: 5, day: 11),
                    startTime: transferDate(2026, 5, 11, 8, 30),
                    endTime: transferDate(2026, 5, 11, 17, 15),
                    targetWorkDurationMinutes: 450,
                    lunchDurationMinutes: 45,
                    additionalBreaks: [
                        WorkBreak(name: "Coffee", durationMinutes: 10),
                        WorkBreak(name: "Walk", durationMinutes: 15)
                    ],
                    notes: "CSV test"
                )
            ]
        )

        let data = try service.exportData(state: state, format: .csv)
        let imported = try service.importData(data, format: .csv)

        #expect(imported.settings == nil)
        #expect(imported.entries.count == 1)
        #expect(imported.entries.first?.date.id == "2026-05-11")
        #expect(imported.entries.first?.targetWorkDurationMinutes == 450)
        #expect(imported.entries.first?.lunchDurationMinutes == 45)
        #expect(imported.entries.first?.additionalBreaks.map(\.name) == ["Coffee", "Walk"])
        #expect(imported.entries.first?.notes == "CSV test")
    }

    @Test
    func importRejectsDuplicateDatesInsideFile() throws {
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
