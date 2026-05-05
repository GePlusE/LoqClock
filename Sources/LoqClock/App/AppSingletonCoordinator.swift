import AppKit

@MainActor
struct RunningApplicationSnapshot: Equatable, Sendable {
    let processIdentifier: pid_t
}

@MainActor
struct AppSingletonCoordinator {
    let currentProcessIdentifier: pid_t
    let bundleIdentifier: String?
    let runningApplications: (String) -> [RunningApplicationSnapshot]
    let activateExistingInstance: (RunningApplicationSnapshot) -> Void
    let terminateCurrentInstance: () -> Void

    init(
        currentProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        runningApplications: @escaping (String) -> [RunningApplicationSnapshot] = { bundleIdentifier in
            NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .map { RunningApplicationSnapshot(processIdentifier: $0.processIdentifier) }
        },
        activateExistingInstance: @escaping (RunningApplicationSnapshot) -> Void = { snapshot in
            guard
                let existingApp = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                    .first(where: { $0.processIdentifier == snapshot.processIdentifier })
            else {
                return
            }

            existingApp.activate()
        },
        terminateCurrentInstance: @escaping () -> Void = {
            NSApp.terminate(nil)
        }
    ) {
        self.currentProcessIdentifier = currentProcessIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.runningApplications = runningApplications
        self.activateExistingInstance = activateExistingInstance
        self.terminateCurrentInstance = terminateCurrentInstance
    }

    @discardableResult
    func terminateIfDuplicateLaunch() -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        let otherInstance = runningApplications(bundleIdentifier)
            .first(where: { $0.processIdentifier != currentProcessIdentifier })

        guard let otherInstance else {
            return false
        }

        activateExistingInstance(otherInstance)
        terminateCurrentInstance()
        return true
    }
}
