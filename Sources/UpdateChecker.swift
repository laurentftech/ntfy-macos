import Foundation

/// Periodically checks GitHub for a newer release and surfaces it in the menu bar
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/laurentftech/ntfy-macos/releases/latest")!
    static let releasePagePrefix = "https://github.com/laurentftech/ntfy-macos/releases/"
    static let upgradeCommand = "brew update && brew upgrade ntfy-macos && brew services restart ntfy-macos"

    private static let initialDelay: TimeInterval = 30
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let lastNotifiedVersionKey = "lastNotifiedUpdateVersion"

    struct Release: Decodable {
        let tagName: String
        let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    private var timer: Timer?
    private let session: URLSession
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    /// Starts periodic checks (no-op if already started or running a dev build)
    func start() {
        guard timer == nil else { return }
        guard Self.parseVersion(AppConstants.effectiveVersion) != nil else {
            Log.info("Update check skipped for development build")
            return
        }

        // Delay the first check so it doesn't compete with server connections at launch
        Timer.scheduledTimer(withTimeInterval: Self.initialDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.checkNow()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkNow()
            }
        }
    }

    func checkNow() async {
        // Re-read config each time so reloads can turn the check on or off
        guard ConfigManager.shared.config?.shouldCheckForUpdates ?? true else { return }

        let release: Release
        do {
            release = try await fetchLatestRelease()
        } catch {
            Log.info("Update check failed: \(error.localizedDescription)")
            return
        }

        guard Self.isVersion(release.tagName, newerThan: AppConstants.effectiveVersion) else { return }

        // Only link to this repository's release pages
        let releaseURL = release.htmlUrl.hasPrefix(Self.releasePagePrefix) ? release.htmlUrl : Self.releasePagePrefix + "latest"

        Log.info("Update available: \(release.tagName) (current: \(AppConstants.effectiveVersion))")
        StatusBarController.shared.showUpdateAvailable(version: release.tagName, releaseURL: releaseURL)

        // Notify once per version; the menu item stays visible regardless
        if defaults.string(forKey: Self.lastNotifiedVersionKey) != release.tagName {
            defaults.set(release.tagName, forKey: Self.lastNotifiedVersionKey)
            NotificationManager.shared.showUpdateNotification(version: release.tagName)
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ntfy-macos/\(AppConstants.effectiveVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    // MARK: - Version Comparison

    /// Parses "1.2.6" or "v1.2.6" into numeric components; returns nil for anything else (e.g. "dev", "1.3.0-beta")
    nonisolated static func parseVersion(_ string: String) -> [Int]? {
        let trimmed = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        return parts.compactMap { $0 }
    }

    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard let lhs = parseVersion(candidate), let rhs = parseVersion(current) else { return false }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }
}
