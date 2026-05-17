import Foundation
import Testing
@testable import LoqClock

struct AppUpdateServiceTests {
    @Test
    func comparesSemanticVersionsCorrectly() throws {
        let service = AppUpdateService(
            currentVersion: { "1.2.3" },
            fetchLatestStableRelease: {
                AppReleaseInfo(
                    version: "v1.2.4",
                    releasePageURL: URL(string: "https://example.com")!,
                    downloadURL: nil,
                    publishedAt: nil
                )
            }
        )

        #expect(try service.compareVersions("1.2.3", "1.2.4") == .orderedAscending)
        #expect(try service.compareVersions("1.2.3", "v1.2.3") == .orderedSame)
        #expect(try service.compareVersions("1.3", "1.2.9") == .orderedDescending)
    }

    @Test
    func rejectsUnsupportedVersions() {
        let service = AppUpdateService(
            currentVersion: { "1.0.0" },
            fetchLatestStableRelease: {
                AppReleaseInfo(
                    version: "latest",
                    releasePageURL: URL(string: "https://example.com")!,
                    downloadURL: nil,
                    publishedAt: nil
                )
            }
        )

        #expect(throws: AppUpdateError.self) {
            _ = try service.compareVersions("1.0.0", "latest")
        }
    }

    @Test
    func noPublishedReleaseHasFriendlyMessage() {
        #expect(AppUpdateError.noPublishedRelease.localizedDescription == "No public LoqClock release is available yet.")
    }
}
