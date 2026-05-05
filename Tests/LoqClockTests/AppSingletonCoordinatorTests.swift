import AppKit
import Testing
@testable import LoqClock

@MainActor
struct AppSingletonCoordinatorTests {
    @Test
    func doesNothingWhenNoBundleIdentifierExists() {
        var didTerminate = false
        var activatedProcess: pid_t?

        let coordinator = AppSingletonCoordinator(
            currentProcessIdentifier: 100,
            bundleIdentifier: nil,
            runningApplications: { _ in
                [RunningApplicationSnapshot(processIdentifier: 200)]
            },
            activateExistingInstance: { snapshot in
                activatedProcess = snapshot.processIdentifier
            },
            terminateCurrentInstance: {
                didTerminate = true
            }
        )

        let terminated = coordinator.terminateIfDuplicateLaunch()

        #expect(terminated == false)
        #expect(didTerminate == false)
        #expect(activatedProcess == nil)
    }

    @Test
    func doesNothingWhenCurrentInstanceIsOnlyInstance() {
        var didTerminate = false
        var activatedProcess: pid_t?

        let coordinator = AppSingletonCoordinator(
            currentProcessIdentifier: 100,
            bundleIdentifier: "com.gepluse.loqclock",
            runningApplications: { _ in
                [RunningApplicationSnapshot(processIdentifier: 100)]
            },
            activateExistingInstance: { snapshot in
                activatedProcess = snapshot.processIdentifier
            },
            terminateCurrentInstance: {
                didTerminate = true
            }
        )

        let terminated = coordinator.terminateIfDuplicateLaunch()

        #expect(terminated == false)
        #expect(didTerminate == false)
        #expect(activatedProcess == nil)
    }

    @Test
    func activatesExistingInstanceAndTerminatesDuplicateLaunch() {
        var didTerminate = false
        var activatedProcess: pid_t?

        let coordinator = AppSingletonCoordinator(
            currentProcessIdentifier: 200,
            bundleIdentifier: "com.gepluse.loqclock",
            runningApplications: { _ in
                [
                    RunningApplicationSnapshot(processIdentifier: 100),
                    RunningApplicationSnapshot(processIdentifier: 200)
                ]
            },
            activateExistingInstance: { snapshot in
                activatedProcess = snapshot.processIdentifier
            },
            terminateCurrentInstance: {
                didTerminate = true
            }
        )

        let terminated = coordinator.terminateIfDuplicateLaunch()

        #expect(terminated == true)
        #expect(didTerminate == true)
        #expect(activatedProcess == 100)
    }
}
