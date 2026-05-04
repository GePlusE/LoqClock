import SwiftUI

struct SettingsWindowView: View {
    @Bindable var store: LoqClockStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsEditorView(
            settings: store.settings,
            launchAtLoginErrorMessage: store.launchAtLoginErrorMessage,
            onCancel: { dismiss() }
        ) { settings in
            store.updateSettings(settings)
        } onToggleLaunchAtLogin: { enabled in
            store.setLaunchAtLoginEnabled(enabled)
        }
    }
}
