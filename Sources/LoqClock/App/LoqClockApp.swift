import SwiftUI

@main
struct LoqClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LoqClockStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Image(systemName: "deskclock")
                .accessibilityLabel("LoqClock")
        }
        .menuBarExtraStyle(.window)
    }
}
