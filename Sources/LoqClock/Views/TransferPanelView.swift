import SwiftUI

struct TransferPanelView: View {
    let statusMessage: String?
    let onClose: () -> Void
    let onExportJSON: () -> Void
    let onExportCSV: () -> Void
    let onImportJSON: () -> Void
    let onImportCSV: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Import / Export")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("Close") {
                    onClose()
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Button("Export JSON") {
                            onExportJSON()
                        }

                        Button("Export CSV") {
                            onExportCSV()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Button("Import JSON") {
                            onImportJSON()
                        }

                        Button("Import CSV") {
                            onImportCSV()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button("Done") {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
