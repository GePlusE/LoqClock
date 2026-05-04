import SwiftUI

@main
struct LoqClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "deskclock")
                .accessibilityLabel("LoqClock")
        }
        .menuBarExtraStyle(.window)
    }
}
