import Foundation
import Testing
@testable import LoqClock

@MainActor
struct LoqClockStoreTests {
    @Test
    func defaultsLoadWhenNoStateExists() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        #expect(store.settings == .default)
        #expect(store.entries.isEmpty)
    }

    @Test
    func createUpdateAndDeleteEntryRoundTrips() {
        let persistence = LoqClockPersistence.memory()
        let store = LoqClockStore(
            persistence: persistence,
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let day = LocalDay(year: 2026, month: 5, day: 4)

        var entry = store.ensureEntry(for: day, now: referenceDate)
        entry.startTime = referenceDate
        entry.endTime = referenceDate.addingTimeInterval(8 * 60 * 60)
        entry.targetWorkDurationMinutes = 240
        entry.lunchDurationMinutes = 15
        entry.additionalBreaks = [WorkBreak(name: "Coffee", durationMinutes: 10)]
        store.createOrUpdateEntry(entry, now: referenceDate)

        let reloaded = LoqClockStore(
            persistence: persistence,
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        #expect(reloaded.entry(for: day)?.targetWorkDurationMinutes == 240)
        #expect(reloaded.entry(for: day)?.lunchDurationMinutes == 15)
        #expect(reloaded.entry(for: day)?.additionalBreaks.map(\.name) == ["Coffee"])
        #expect(reloaded.entry(for: day)?.additionalBreaks.map(\.durationMinutes) == [10])

        reloaded.deleteEntry(for: day)

        let afterDelete = LoqClockStore(
            persistence: persistence,
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        #expect(afterDelete.entry(for: day) == nil)
    }

    @Test
    func updatingSettingsPersistsDefaults() {
        let persistence = LoqClockPersistence.memory()
        let store = LoqClockStore(
            persistence: persistence,
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        store.updateSettings(
            AppSettings(
                defaultTargetWorkDurationMinutes: 360,
                defaultLunchDurationMinutes: 30,
                launchAtLoginEnabled: false,
                launchAtLoginPromptHandled: false,
                automaticallyCheckForUpdates: true,
                lastSuccessfulUpdateCheckAt: nil
            )
        )

        let reloaded = LoqClockStore(
            persistence: persistence,
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        #expect(reloaded.settings.defaultTargetWorkDurationMinutes == 360)
        #expect(reloaded.settings.defaultLunchDurationMinutes == 30)
    }

    @Test
    func newEntriesUseCurrentSettingsAsPrefill() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let day = LocalDay(year: 2026, month: 5, day: 7)

        store.updateSettings(
            AppSettings(
                defaultTargetWorkDurationMinutes: 300,
                defaultLunchDurationMinutes: 45,
                launchAtLoginEnabled: false,
                launchAtLoginPromptHandled: false,
                automaticallyCheckForUpdates: true,
                lastSuccessfulUpdateCheckAt: nil
            )
        )

        let entry = store.ensureEntry(for: day, now: referenceDate)

        #expect(entry.targetWorkDurationMinutes == 300)
        #expect(entry.lunchDurationMinutes == 45)
    }

    @Test
    func perDayOverridesFeedIntoCalculations() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let day = LocalDay(year: 2026, month: 5, day: 8)

        store.upsertEntry(for: day, now: referenceDate) { entry in
            entry.startTime = referenceDate
            entry.endTime = referenceDate.addingTimeInterval(4 * 60 * 60)
            entry.targetWorkDurationMinutes = 240
            entry.lunchDurationMinutes = 0
            entry.additionalBreaks = [WorkBreak(name: "Walk", durationMinutes: 30)]
        }

        let savedEntry = store.entry(for: day)

        #expect(savedEntry?.targetWorkDurationMinutes == 240)
        #expect(savedEntry?.lunchDurationMinutes == 0)
        #expect(savedEntry?.additionalBreaks.map(\.name) == ["Walk"])
        #expect(savedEntry?.additionalBreaks.map(\.durationMinutes) == [30])
        #expect(savedEntry.map { store.calculator.dailyBalanceMinutes(for: $0) } == -30)
    }

    @Test
    func startAndEndTodayActionsPersistSessionState() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let start = referenceDate
        let end = referenceDate.addingTimeInterval(8 * 60 * 60)
        let day = LocalDay(date: start, calendar: testCalendar)

        store.startToday(now: start)

        #expect(store.entry(for: day)?.startTime == start)
        #expect(store.entry(for: day)?.endTime == nil)

        store.endToday(now: end)

        #expect(store.entry(for: day)?.endTime == end)

        store.clearTodayEndTime(now: end)

        #expect(store.entry(for: day)?.endTime == nil)
        #expect(store.entry(for: day)?.sessions.count == 2)
        #expect(store.entry(for: day)?.sessions.filter { $0.endTimestamp == nil }.count == 1)
    }

    @Test
    func startAndEndActionsNormalizeMinutesAndDiscardZeroMinuteSessions() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let start = Date(timeIntervalSince1970: 1_777_680_030)
        let stop = Date(timeIntervalSince1970: 1_777_680_031)
        let day = LocalDay(date: start, calendar: testCalendar)

        store.startToday(now: start)
        store.endToday(now: stop)

        #expect(store.entry(for: day)?.sessions.count == 1)
        #expect(store.entry(for: day)?.sessions.first?.startTimestamp == Date(timeIntervalSince1970: 1_777_680_000))
        #expect(store.entry(for: day)?.sessions.first?.endTimestamp == Date(timeIntervalSince1970: 1_777_680_060))
    }

    @Test
    func accidentalStartStopWithinSameNormalizedMinuteIsDiscarded() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let start = Date(timeIntervalSince1970: 1_777_680_000)
        let stop = Date(timeIntervalSince1970: 1_777_680_000)
        let day = LocalDay(date: start, calendar: testCalendar)

        store.startToday(now: start)
        store.endToday(now: stop)

        #expect(store.entry(for: day) == nil)
    }

    @Test
    func startingWorkDoesNotCreateSecondActiveSession() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let start = referenceDate
        let later = referenceDate.addingTimeInterval(30 * 60)
        let day = LocalDay(date: start, calendar: testCalendar)

        store.startToday(now: start)
        store.startToday(now: later)

        #expect(store.entry(for: day)?.sessions.count == 1)
        #expect(store.entry(for: day)?.sessions.filter { $0.endTimestamp == nil }.count == 1)
    }

    @Test
    func importConflictStrategyCanReplaceOrSkipExistingDates() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )
        let day = LocalDay(year: 2026, month: 5, day: 9)

        store.createOrUpdateEntry(
            WorkDayEntry(
                date: day,
                startTime: referenceDate,
                endTime: referenceDate.addingTimeInterval(8 * 60 * 60),
                targetWorkDurationMinutes: 480,
                lunchDurationMinutes: 60,
                notes: "Original"
            ),
            now: referenceDate
        )

        let imported = ImportedEntryPayload(
            settings: nil,
            entries: [
                WorkDayEntry(
                    date: day,
                    startTime: referenceDate,
                    endTime: referenceDate.addingTimeInterval(4 * 60 * 60),
                    targetWorkDurationMinutes: 240,
                    lunchDurationMinutes: 0,
                    notes: "Imported"
                )
            ]
        )

        let skipSummary = store.applyImportedPayload(imported, strategy: .skipExisting)
        #expect(skipSummary.importedCount == 0)
        #expect(skipSummary.skippedCount == 1)
        #expect(store.entry(for: day)?.notes == "Original")

        let replaceSummary = store.applyImportedPayload(imported, strategy: .replaceExisting)
        #expect(replaceSummary.importedCount == 1)
        #expect(replaceSummary.replacedCount == 1)
        #expect(store.entry(for: day)?.notes == "Imported")
        #expect(store.entry(for: day)?.targetWorkDurationMinutes == 240)
    }

    @Test
    func launchAtLoginPromptAppearsAfterMeaningfulUseAndCanBeHandled() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock()
        )

        #expect(store.shouldShowLaunchAtLoginPrompt == false)

        _ = store.ensureEntry(for: LocalDay(year: 2026, month: 5, day: 4), now: referenceDate)

        #expect(store.shouldShowLaunchAtLoginPrompt == true)

        store.handleLaunchAtLoginPrompt(enable: false)

        #expect(store.shouldShowLaunchAtLoginPrompt == false)
        #expect(store.settings.launchAtLoginPromptHandled == true)
    }

    @Test
    func launchAtLoginToggleTracksActualOutcome() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(initiallyEnabled: false)
        )

        let enabled = store.setLaunchAtLoginEnabled(true)

        #expect(enabled == true)
        #expect(store.settings.launchAtLoginEnabled == true)
        #expect(store.launchAtLoginErrorMessage == nil)
    }

    @Test
    func automaticUpdateChecksRequireExplicitOptIn() {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock()
        )

        #expect(store.shouldPerformAutomaticUpdateCheck(now: referenceDate) == false)

        store.setAutomaticUpdateChecksEnabled(true)

        #expect(store.shouldPerformAutomaticUpdateCheck(now: referenceDate) == true)
    }

    @Test
    func automaticUpdateCheckWaitsSevenDaysAfterSuccess() {
        let lastCheck = referenceDate
        let store = LoqClockStore(
            persistence: .memory(
                initialState: AppState(
                    settings: AppSettings(
                        defaultTargetWorkDurationMinutes: 480,
                        defaultLunchDurationMinutes: 60,
                        launchAtLoginEnabled: false,
                        launchAtLoginPromptHandled: false,
                        automaticallyCheckForUpdates: true,
                        lastSuccessfulUpdateCheckAt: lastCheck
                    )
                )
            ),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock()
        )

        #expect(store.shouldPerformAutomaticUpdateCheck(now: lastCheck.addingTimeInterval(6 * 24 * 60 * 60)) == false)
        #expect(store.shouldPerformAutomaticUpdateCheck(now: lastCheck.addingTimeInterval(7 * 24 * 60 * 60)) == true)
    }

    @Test
    func manualUpdateCheckStoresAvailableReleaseAndTimestamp() async throws {
        let release = AppReleaseInfo(
            version: "v9.9.9",
            releasePageURL: URL(string: "https://example.com/release")!,
            downloadURL: URL(string: "https://example.com/release.dmg")!,
            publishedAt: nil
        )
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock(
                currentVersion: "0.1.0",
                latestRelease: release
            )
        )

        try await store.checkForUpdates(manual: true, now: referenceDate)

        #expect(store.availableUpdate == release)
        #expect(store.settings.lastSuccessfulUpdateCheckAt == referenceDate)
        #expect(store.updateCheckErrorMessage == nil)
        #expect(store.updateCheckStatusMessage == nil)
    }

    @Test
    func manualUpdateCheckReportsErrors() async {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock(error: AppUpdateError.invalidResponse)
        )

        await #expect(throws: AppUpdateError.self) {
            try await store.checkForUpdates(manual: true, now: referenceDate)
        }

        #expect(store.updateCheckErrorMessage == AppUpdateError.invalidResponse.localizedDescription)
    }

    @Test
    func manualUpdateCheckReportsMissingPublicReleaseAsStatus() async throws {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock(error: AppUpdateError.noPublishedRelease)
        )

        try await store.checkForUpdates(manual: true, now: referenceDate)

        #expect(store.updateCheckErrorMessage == nil)
        #expect(store.updateCheckStatusMessage == AppUpdateError.noPublishedRelease.localizedDescription)
        #expect(store.availableUpdate == nil)
    }

    @Test
    func manualUpdateCheckReportsUpToDateStatus() async throws {
        let store = LoqClockStore(
            persistence: .memory(),
            calendar: testCalendar,
            launchAtLoginService: .mock(),
            appUpdateService: .mock(currentVersion: "0.1.0")
        )

        try await store.checkForUpdates(manual: true, now: referenceDate)

        #expect(store.availableUpdate == nil)
        #expect(store.updateCheckStatusMessage == "LoqClock is up to date.")
    }
}

private let testCalendar = Calendar(identifier: .gregorian)
private let referenceDate = Date(timeIntervalSince1970: 1_777_680_000)

extension LaunchAtLoginService {
    static func mock(
        initiallyEnabled: Bool = false,
        failOnSet: Bool = false
    ) -> LaunchAtLoginService {
        final class Storage {
            var enabled: Bool

            init(enabled: Bool) {
                self.enabled = enabled
            }
        }

        let storage = Storage(enabled: initiallyEnabled)

        return LaunchAtLoginService(
            currentState: { storage.enabled },
            setEnabled: { enabled in
                if failOnSet {
                    throw LaunchAtLoginError.registrationFailed("Mock launch-at-login failure.")
                }

                storage.enabled = enabled
                return storage.enabled
            }
        )
    }
}

extension AppUpdateService {
    static func mock(
        currentVersion: String = "0.1.0",
        latestRelease: AppReleaseInfo = AppReleaseInfo(
            version: "v0.1.0",
            releasePageURL: URL(string: "https://example.com/release")!,
            downloadURL: URL(string: "https://example.com/release.dmg")!,
            publishedAt: nil
        ),
        error: Error? = nil
    ) -> AppUpdateService {
        AppUpdateService(
            currentVersion: { currentVersion },
            fetchLatestStableRelease: {
                if let error {
                    throw error
                }

                return latestRelease
            }
        )
    }
}
