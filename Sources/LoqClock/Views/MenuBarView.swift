import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var store: LoqClockStore
    @Environment(\.openWindow) private var openWindow
    @State private var activePanel: ActivePanel?

    private enum ActivePanel {
        case entryEditor
        case transfer
    }
    @State private var transferStatusMessage: String?

    private var today: LocalDay {
        LocalDay(date: .now, calendar: store.calendar)
    }

    private var todaysEntry: WorkDayEntry? {
        store.entry(for: today)
    }

    private var totalBalanceMinutes: Int {
        store.calculator.totalBalanceMinutes(for: store.entries)
    }

    private var weekBalanceMinutes: Int {
        store.calculator.weekBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    private var monthBalanceMinutes: Int {
        store.calculator.monthBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    private var yearBalanceMinutes: Int {
        store.calculator.yearBalanceMinutes(for: store.entries, relativeTo: .now)
    }

    private var isTodayInProgress: Bool {
        guard let todaysEntry else {
            return false
        }

        return todaysEntry.startTime != nil && todaysEntry.endTime == nil
    }

    private var todayStatusTitle: String {
        guard let todaysEntry else {
            return "Ready"
        }

        if todaysEntry.startTime == nil {
            return "Ready"
        }

        return todaysEntry.endTime == nil ? "Working" : "Finished"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: isTodayInProgress ? 60 : 3600)) { context in
            VStack(alignment: .leading, spacing: 16) {
                if activePanel == .entryEditor {
                    EntryEditorView(
                        day: today,
                        settings: store.settings,
                        existingEntry: todaysEntry,
                        calendar: store.calendar,
                        onCancel: { activePanel = nil }
                    ) { entry in
                        store.createOrUpdateEntry(entry)
                    }
                } else if activePanel == .transfer {
                    TransferPanelView(
                        statusMessage: transferStatusMessage,
                        onClose: { activePanel = nil },
                        onExportJSON: { exportEntries(format: .json) },
                        onExportCSV: { exportEntries(format: .csv) },
                        onImportJSON: { importEntries(format: .json) },
                        onImportCSV: { importEntries(format: .csv) }
                    )
                } else {
                    overviewContent(now: context.date)
                }
            }
            .padding(18)
            .frame(width: panelWidth)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func overviewContent(now: Date) -> some View {
        let totalBalance = store.calculator.totalBalanceMinutes(for: store.entries, now: now)
        let weekBalance = store.calculator.weekBalanceMinutes(for: store.entries, relativeTo: now, now: now)
        let monthBalance = store.calculator.monthBalanceMinutes(for: store.entries, relativeTo: now, now: now)
        let yearBalance = store.calculator.yearBalanceMinutes(for: store.entries, relativeTo: now, now: now)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LoqClock")
                        .font(.title3.weight(.semibold))

                    Text(isTodayInProgress ? "Today is running and updates live." : "Manual tracking with instant local updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(
                    title: todayStatusTitle,
                    tone: statusTone
                )
            }

            if store.shouldShowLaunchAtLoginPrompt {
                SectionCard(title: "Launch at Login") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Launch LoqClock automatically when you log in?")
                            .font(.subheadline)

                        Text("You can change this later in Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            ActionButton(title: "Enable") {
                                store.handleLaunchAtLoginPrompt(enable: true)
                            }

                            ActionButton(title: "Not now") {
                                store.handleLaunchAtLoginPrompt(enable: false)
                            }
                        }

                        if let launchAtLoginErrorMessage = store.launchAtLoginErrorMessage {
                            Text(launchAtLoginErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            SectionCard(title: "Today") {
                if let todaysEntry {
                    let extraBreakSummary = extraBreakSummary(for: todaysEntry)
                    let netWorked = store.calculator.netWorkedMinutes(for: todaysEntry, now: now)
                    let dailyBalance = store.calculator.dailyBalanceMinutes(for: todaysEntry, now: now)
                    PlaceholderRow(title: "Start", value: timeText(todaysEntry.startTime))
                    PlaceholderRow(
                        title: "End",
                        value: todaysEntry.endTime == nil && todaysEntry.startTime != nil ? "In progress" : timeText(todaysEntry.endTime)
                    )
                    PlaceholderRow(title: "Target", value: durationText(todaysEntry.targetWorkDurationMinutes))
                    PlaceholderRow(title: "Lunch", value: durationText(todaysEntry.lunchDurationMinutes))
                    if let extraBreakSummary {
                        PlaceholderRow(title: "Extra Breaks", value: extraBreakSummary)
                    }
                    PlaceholderRow(
                        title: "Net Worked Today",
                        value: durationText(netWorked)
                    )
                    PlaceholderRow(
                        title: "Daily Balance",
                        value: signedDurationText(dailyBalance)
                    )
                    PlaceholderRow(
                        title: "Leave at 0 Today",
                        value: timeText(store.calculator.leaveTimeForZeroToday(for: todaysEntry))
                    )
                    PlaceholderRow(
                        title: "Leave at 0 Week",
                        value: timeText(
                            store.calculator.leaveTimeForZeroWeek(
                                todayEntry: todaysEntry,
                                allEntries: store.entries
                            )
                        )
                    )
                } else {
                    PlaceholderRow(title: "Today", value: "No local entry")
                }
            }

            SectionCard(title: "Leave Times") {
                if let todaysEntry {
                    PlaceholderRow(
                        title: "0 Today",
                        value: timeText(store.calculator.leaveTimeForZeroToday(for: todaysEntry))
                    )
                    PlaceholderRow(
                        title: "0 This Week",
                        value: timeText(
                            store.calculator.leaveTimeForZeroWeek(
                                todayEntry: todaysEntry,
                                allEntries: store.entries
                            )
                        )
                    )
                } else {
                    PlaceholderRow(title: "Status", value: "Start today to see leave times")
                }
            }

            SectionCard(title: "Balances") {
                PlaceholderRow(title: "Total", value: signedDurationText(totalBalance))
                PlaceholderRow(title: "Week", value: signedDurationText(weekBalance))
                PlaceholderRow(title: "Month", value: signedDurationText(monthBalance))
                PlaceholderRow(title: "Year", value: signedDurationText(yearBalance))
            }

            SectionCard(title: "Defaults") {
                PlaceholderRow(title: "Stored Entries", value: "\(store.entries.count)")
                PlaceholderRow(title: "Target", value: durationText(store.settings.defaultTargetWorkDurationMinutes))
                PlaceholderRow(title: "Lunch", value: durationText(store.settings.defaultLunchDurationMinutes))
            }

            SectionCard(title: "Actions") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ActionButton(title: isTodayInProgress ? "Restart Start" : "Start Day") {
                            store.startToday(now: now)
                        }

                        ActionButton(title: isTodayInProgress ? "End Day" : "Set End Time") {
                            store.endToday(now: now)
                        }
                        .disabled(todaysEntry == nil && !isTodayInProgress)
                    }

                    HStack(spacing: 10) {
                        ActionButton(title: todaysEntry == nil ? "Create Today" : "Edit Today") {
                            if todaysEntry == nil {
                                _ = store.ensureEntry(for: today)
                            }
                            activePanel = .entryEditor
                        }

                        if todaysEntry?.endTime != nil {
                            ActionButton(title: "Resume Today") {
                                store.clearTodayEndTime(now: now)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        ActionButton(title: "Settings") {
                            openWindow(id: "settings")
                        }

                        ActionButton(title: "Import / Export") {
                            activePanel = .transfer
                        }
                    }

                    HStack(spacing: 10) {
                        ActionButton(title: "History") {
                            openWindow(id: "history")
                        }

                        ActionButton(title: "Delete Today", role: .destructive) {
                            store.deleteEntry(for: today)
                        }
                        .disabled(todaysEntry == nil)

                        Spacer()

                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if let transferStatusMessage {
                Text(transferStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Reference: PRODUCT_SPEC.md")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusTone: StatusBadge.Tone {
        guard let todaysEntry else {
            return .neutral
        }

        if todaysEntry.startTime == nil {
            return .neutral
        }

        return todaysEntry.endTime == nil ? .active : .complete
    }

    private func durationText(_ minutes: Int) -> String {
        let absoluteMinutes = abs(minutes)
        let hours = absoluteMinutes / 60
        let remainingMinutes = absoluteMinutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func signedDurationText(_ minutes: Int) -> String {
        let prefix = minutes < 0 ? "-" : "+"
        return "\(prefix)\(durationText(minutes))"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    private func extraBreakSummary(for entry: WorkDayEntry) -> String? {
        guard !entry.additionalBreaks.isEmpty else {
            return nil
        }

        let totalMinutes = entry.additionalBreaks.reduce(0) { $0 + $1.durationMinutes }
        return "\(durationText(totalMinutes)) across \(entry.additionalBreaks.count)"
    }

    private func exportEntries(format: EntryTransferFormat) {
        do {
            let data = try store.exportStateData(format: format)
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "LoqClock-export.\(format.fileExtension)"

            guard panel.runModal() == .OK, let url = panel.url else {
                transferStatusMessage = EntryTransferError.noFileSelected.localizedDescription
                return
            }

            try data.write(to: url, options: .atomic)
            transferStatusMessage = "Exported \(store.entries.count) entries as \(format.rawValue.uppercased())."
        } catch {
            transferStatusMessage = error.localizedDescription
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func importEntries(format: EntryTransferFormat) {
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false

            guard panel.runModal() == .OK, let url = panel.url else {
                transferStatusMessage = EntryTransferError.noFileSelected.localizedDescription
                return
            }

            let data = try Data(contentsOf: url)
            let payload = try store.transferService.importData(data, format: format)
            let duplicates = store.duplicateImportDates(for: payload)

            let strategy: ImportConflictStrategy?
            if duplicates.isEmpty {
                strategy = .replaceExisting
            } else {
                strategy = promptConflictStrategy(for: duplicates)
            }

            guard let strategy else {
                transferStatusMessage = "Import cancelled."
                return
            }

            let summary = store.applyImportedPayload(payload, strategy: strategy)
            transferStatusMessage = importStatusMessage(summary)
        } catch let error as EntryTransferError {
            transferStatusMessage = error.localizedDescription
            showAlert(title: "Import Failed", message: error.localizedDescription)
        } catch {
            transferStatusMessage = error.localizedDescription
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func promptConflictStrategy(for duplicates: [LocalDay]) -> ImportConflictStrategy? {
        let alert = NSAlert()
        alert.messageText = "Imported dates already exist"
        alert.informativeText = "Choose how to handle \(duplicates.count) duplicate date(s): \(duplicates.map(\.id).joined(separator: ", "))."
        alert.addButton(withTitle: "Replace Existing")
        alert.addButton(withTitle: "Skip Existing")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .replaceExisting
        case .alertSecondButtonReturn:
            return .skipExisting
        default:
            return nil
        }
    }

    private func importStatusMessage(_ summary: ImportApplicationSummary) -> String {
        var parts: [String] = ["Imported \(summary.importedCount) entries"]

        if summary.replacedCount > 0 {
            parts.append("replaced \(summary.replacedCount)")
        }

        if summary.skippedCount > 0 {
            parts.append("skipped \(summary.skippedCount)")
        }

        if summary.settingsUpdated {
            parts.append("updated settings")
        }

        return parts.joined(separator: ", ") + "."
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private var panelWidth: CGFloat {
        switch activePanel {
        case .transfer:
            return 380
        case .entryEditor:
            return 360
        case nil:
            return 320
        }
    }
}

private struct PlaceholderRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }
}

private struct StatusBadge: View {
    enum Tone {
        case neutral
        case active
        case complete

        var color: Color {
            switch self {
            case .neutral: return .secondary
            case .active: return .green
            case .complete: return .blue
            }
        }
    }

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.color.opacity(0.14), in: Capsule())
            .foregroundStyle(tone.color)
    }
}

private struct ActionButton: View {
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
