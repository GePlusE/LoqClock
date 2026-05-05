import AppKit
import SwiftUI

@main
struct LoqClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LoqClockStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .task {
                    await store.performAutomaticUpdateCheckIfNeeded()
                }
        } label: {
            Image(systemName: "deskclock")
                .accessibilityLabel("LoqClock")
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindowView(store: store)
        }
        .windowResizability(.contentSize)

        Window("History", id: "history") {
            HistoryWindowView(store: store)
        }
        .windowResizability(.contentSize)
    }
}
