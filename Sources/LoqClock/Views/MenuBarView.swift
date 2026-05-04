import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LoqClock")
                    .font(.title3.weight(.semibold))

                Text("Menu bar shell ready for MVP implementation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                PlaceholderRow(title: "Today", value: "Coming next")
                PlaceholderRow(title: "Leave Times", value: "Coming next")
                PlaceholderRow(title: "Balances", value: "Coming next")
            }

            Divider()

            Text("Reference: PRODUCT_SPEC.md")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(width: 320)
        .background(.regularMaterial)
    }
}

private struct PlaceholderRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
