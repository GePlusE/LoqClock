import Foundation

struct AppReleaseInfo: Equatable, Sendable {
    let version: String
    let releasePageURL: URL
    let downloadURL: URL?
    let publishedAt: Date?
}

enum AppUpdateError: LocalizedError {
    case invalidResponse
    case noPublishedRelease
    case unsupportedVersion(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "LoqClock could not read the latest release information from GitHub."
        case .noPublishedRelease:
            return "No public LoqClock release is available yet."
        case .unsupportedVersion(let version):
            return "LoqClock could not compare the latest release version (\(version))."
        }
    }
}

struct AppUpdateService {
    let currentVersion: () -> String
    let fetchLatestStableRelease: () async throws -> AppReleaseInfo

    func isUpdateAvailable(comparedTo release: AppReleaseInfo) throws -> Bool {
        try compareVersions(currentVersion(), release.version) == .orderedAscending
    }

    func compareVersions(_ lhs: String, _ rhs: String) throws -> ComparisonResult {
        let lhsComponents = try normalizedComponents(for: lhs)
        let rhsComponents = try normalizedComponents(for: rhs)
        let maxCount = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<maxCount {
            let lhsValue = index < lhsComponents.count ? lhsComponents[index] : 0
            let rhsValue = index < rhsComponents.count ? rhsComponents[index] : 0

            if lhsValue < rhsValue {
                return .orderedAscending
            }

            if lhsValue > rhsValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private func normalizedComponents(for version: String) throws -> [Int] {
        let sanitized = version.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
        let parts = sanitized.split(separator: ".")

        guard !parts.isEmpty else {
            throw AppUpdateError.unsupportedVersion(version)
        }

        return try parts.map { part in
            guard let value = Int(part) else {
                throw AppUpdateError.unsupportedVersion(version)
            }
            return value
        }
    }
}

extension AppUpdateService {
    static func live(
        session: URLSession = .shared,
        currentVersion: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        }
    ) -> AppUpdateService {
        AppUpdateService(
            currentVersion: currentVersion,
            fetchLatestStableRelease: {
                let url = URL(string: "https://api.github.com/repos/GePlusE/LoqClock/releases/latest")!
                let (data, response) = try await session.data(from: url)

                guard
                    let httpResponse = response as? HTTPURLResponse,
                    200..<300 ~= httpResponse.statusCode
                else {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                        throw AppUpdateError.noPublishedRelease
                    }
                    throw AppUpdateError.invalidResponse
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(GitHubReleasePayload.self, from: data)

                let dmgAsset = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })

                return AppReleaseInfo(
                    version: payload.tagName,
                    releasePageURL: payload.htmlURL,
                    downloadURL: dmgAsset?.browserDownloadURL ?? payload.htmlURL,
                    publishedAt: payload.publishedAt
                )
            }
        )
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let htmlURL: URL
    let publishedAt: Date?
    let assets: [GitHubAssetPayload]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubAssetPayload: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
