import SwiftUI

struct AboutWindowView: View {
    private var versionTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return "Version \(version)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "deskclock")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("LoqClock")
                        .font(.title2.weight(.semibold))

                    Text(versionTitle)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("LoqClock is a local-only macOS menu bar app for work-time tracking and overtime visibility.")
                .foregroundStyle(.secondary)

            Text("No accounts. No cloud sync. No telemetry.")
                .font(.footnote.weight(.semibold))
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
    }
}
