import SwiftUI

struct SettingsWindowView: View {
    @Bindable var store: LoqClockStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsEditorView(
            settings: store.settings,
            launchAtLoginErrorMessage: store.launchAtLoginErrorMessage,
            updateCheckErrorMessage: store.updateCheckErrorMessage,
            updateCheckStatusMessage: store.updateCheckStatusMessage,
            onCancel: { dismiss() }
        ) { settings in
            store.updateSettings(settings)
        } onToggleLaunchAtLogin: { enabled in
            store.setLaunchAtLoginEnabled(enabled)
        } onToggleAutomaticUpdates: { enabled in
            store.setAutomaticUpdateChecksEnabled(enabled)
        } onManualCheckForUpdates: {
            Task {
                try? await store.checkForUpdates(manual: true)
            }
        } onResetTrackingData: {
            store.resetTrackingData()
        } onResetEverything: {
            store.resetEverything()
        }
    }
}
