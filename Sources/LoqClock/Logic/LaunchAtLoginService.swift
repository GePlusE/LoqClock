import Foundation
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let message):
            return message
        }
    }
}

struct LaunchAtLoginService {
    let currentState: () -> Bool
    let setEnabled: (Bool) throws -> Bool

    static func live() -> LaunchAtLoginService {
        LaunchAtLoginService(
            currentState: {
                SMAppService.mainApp.status == .enabled
            },
            setEnabled: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
                }

                return SMAppService.mainApp.status == .enabled
            }
        )
    }
}
