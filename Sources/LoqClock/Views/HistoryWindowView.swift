import SwiftUI

struct HistoryWindowView: View {
    @Bindable var store: LoqClockStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var editingDay: LocalDay?

    var body: some View {
        Group {
            if let editingDay {
                HistoryDayEditorView(
                    day: editingDay,
                    settings: store.settings,
                    calendar: store.calendar,
                    existingEntry: store.entry(for: editingDay),
                    existingDates: Set(store.entries.map(\.date)),
                    onBack: { self.editingDay = nil },
                    onSave: { entry in
                        store.createOrUpdateEntry(entry)
                        selectedDate = entry.date.date(in: store.calendar) ?? selectedDate
                        self.editingDay = entry.date
                    },
                    onDelete: store.entry(for: editingDay) == nil ? nil : {
                        store.deleteEntry(for: editingDay)
                        self.editingDay = nil
                    }
                )
            } else {
                HistoryPanelView(
                    selectedDate: $selectedDate,
                    entries: store.entries,
                    recentEntries: recentEntries,
                    calendar: store.calendar,
                    calculator: store.calculator,
                    onClose: { dismiss() },
                    onOpenSelectedDate: {
                        editingDay = LocalDay(date: selectedDate, calendar: store.calendar)
                    },
                    onOpenEntry: { day in
                        selectedDate = day.date(in: store.calendar) ?? selectedDate
                        editingDay = day
                    }
                )
            }
        }
    }

    private var recentEntries: [WorkDayEntry] {
        Array(store.entries.sorted { $0.date > $1.date }.prefix(8))
    }
}
