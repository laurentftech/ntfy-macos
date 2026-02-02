import Foundation
import Yams

struct NotificationAction: Codable {
    let title: String
    let type: String      // "script" or "view"
    let path: String?     // for scripts
    let url: String?      // for view actions
}

struct TopicConfig: Codable {
    let name: String
    let iconPath: String?
    let iconSymbol: String?
    let autoRunScript: String?
    let silent: Bool?
    let clickUrl: ClickUrlConfig?  // Control click behavior: true/false/custom URL
    let actions: [NotificationAction]?
    let fetchMissed: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case iconPath = "icon_path"
        case iconSymbol = "icon_symbol"
        case autoRunScript = "auto_run_script"
        case silent
        case clickUrl = "click_url"
        case actions
        case fetchMissed = "fetch_missed"
    }

    /// Whether to fetch missed messages for this topic (default: false)
    var shouldFetchMissed: Bool {
        fetchMissed ?? false
    }
}

/// Represents click_url config: can be a URL string, true (use default), or false (disabled)
enum ClickUrlConfig: Codable {
    case enabled          // true or not specified: use webUrl or url
    case disabled         // false: don't open anything on click
    case custom(String)   // custom URL

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = boolValue ? .enabled : .disabled
        } else if let stringValue = try? container.decode(String.self) {
            self = .custom(stringValue)
        } else {
            self = .enabled
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enabled:
            try container.encode(true)
        case .disabled:
            try container.encode(false)
        case .custom(let url):
            try container.encode(url)
        }
    }
}

struct ServerConfig: Codable {
    let url: String
    let token: String?
    let topics: [TopicConfig]
    let allowedSchemes: [String]?
    let allowedDomains: [String]?
    let fetchMissed: Bool?

    enum CodingKeys: String, CodingKey {
        case url
        case token
        case topics
        case allowedSchemes = "allowed_schemes"
        case allowedDomains = "allowed_domains"
        case fetchMissed = "fetch_missed"
    }

    /// Whether to fetch missed messages on reconnect (default: false)
    var shouldFetchMissed: Bool {
        fetchMissed ?? false
    }

    /// Returns the list of allowed URL schemes, defaulting to ["http", "https"]
    var effectiveAllowedSchemes: [String] {
        allowedSchemes ?? ["http", "https"]
    }

    /// Validates if a URL's scheme is allowed for this server
    func isSchemeAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return effectiveAllowedSchemes.map { $0.lowercased() }.contains(scheme)
    }

    /// Validates if a URL's domain is allowed for this server (nil means all domains allowed, empty array means none allowed)
    func isDomainAllowed(_ url: URL) -> Bool {
        guard let allowedDomains = allowedDomains else {
            return true  // No restriction if not configured (nil)
        }
        guard !allowedDomains.isEmpty else {
            return false  // Empty array means no domains allowed
        }
        guard let host = url.host?.lowercased() else { return false }
        return allowedDomains.map { $0.lowercased() }.contains { allowedDomain in
            // Support wildcard subdomains: "*.example.com" matches "sub.example.com"
            if allowedDomain.hasPrefix("*.") {
                let baseDomain = String(allowedDomain.dropFirst(2))
                return host == baseDomain || host.hasSuffix("." + baseDomain)
            }
            return host == allowedDomain
        }
    }

    /// Validates if a URL is allowed (both scheme and domain)
    func isUrlAllowed(_ url: URL) -> Bool {
        return isSchemeAllowed(url) && isDomainAllowed(url)
    }
}

struct AppConfig: Codable {
    let servers: [ServerConfig]

    // Convenience: all topics across all servers
    var allTopics: [TopicConfig] {
        servers.flatMap { $0.topics }
    }

    /// Finds the server config that contains a given topic
    func serverConfig(forTopic topicName: String) -> ServerConfig? {
        return servers.first { server in
            server.topics.contains { $0.name == topicName }
        }
    }
}

enum ConfigError: Error, LocalizedError {
    case fileNotFound
    case invalidYAML(Error)
    case decodingError(Error)
    case insecureFilePermissions(String)
    case unknownKeys(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Configuration file not found"
        case .invalidYAML(let error):
            return "Invalid YAML: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Configuration error: \(error.localizedDescription)"
        case .insecureFilePermissions(let message):
            return message
        case .unknownKeys(let details):
            return "Unknown configuration keys:\n\(details)"
        }
    }
}

final class ConfigManager: @unchecked Sendable {
    static let shared = ConfigManager()
    private let lock = NSLock()
    private var _config: AppConfig?

    var config: AppConfig? {
        lock.lock()
        defer { lock.unlock() }
        return _config
    }

    private init() {}

    /// Default configuration path: ~/.config/ntfy-macos/config.yml
    static var defaultConfigPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/ntfy-macos/config.yml").path
    }

    /// Loads configuration from the specified path or default location
    func loadConfig(from path: String? = nil) throws {
        let configPath = path ?? ConfigManager.defaultConfigPath
        let url = URL(fileURLWithPath: configPath)

        guard FileManager.default.fileExists(atPath: configPath) else {
            throw ConfigError.fileNotFound
        }

        // Validate file permissions - should not be world-writable
        try validateFilePermissions(at: configPath)

        let yamlString: String
        do {
            yamlString = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigError.fileNotFound
        }

        // Validate for unknown keys before decoding (warnings only, doesn't block loading)
        let unknownKeysWarning = checkForUnknownKeys(in: yamlString)

        let decoder = YAMLDecoder()
        do {
            let decodedConfig = try decoder.decode(AppConfig.self, from: yamlString)
            lock.lock()
            defer { lock.unlock() }
            self._config = decodedConfig
            self._configWarning = unknownKeysWarning
        } catch {
            throw ConfigError.decodingError(error)
        }
    }

    /// Warning message for unknown keys (doesn't prevent loading)
    private var _configWarning: String?
    var configWarning: String? {
        lock.lock()
        defer { lock.unlock() }
        return _configWarning
    }

    /// Known keys at each level of the config
    private static let knownRootKeys: Set<String> = ["servers"]
    private static let knownServerKeys: Set<String> = ["url", "token", "topics", "allowed_schemes", "allowed_domains", "fetch_missed"]
    private static let knownTopicKeys: Set<String> = ["name", "icon_path", "icon_symbol", "auto_run_script", "silent", "click_url", "actions", "fetch_missed"]
    private static let knownActionKeys: Set<String> = ["title", "type", "path", "url"]

    /// Checks YAML for unknown keys that would be silently ignored
    /// Returns warning message if unknown keys found, nil otherwise
    private func checkForUnknownKeys(in yamlString: String) -> String? {
        guard let yaml = try? Yams.load(yaml: yamlString) as? [String: Any] else {
            return nil  // Let the decoder handle invalid YAML
        }

        var warnings: [String] = []

        // Check root level
        for key in yaml.keys {
            if !Self.knownRootKeys.contains(key) {
                warnings.append("Unknown key '\(key)' at root level")
            }
        }

        // Check servers
        if let servers = yaml["servers"] as? [[String: Any]] {
            for (serverIndex, server) in servers.enumerated() {
                let serverUrl = server["url"] as? String ?? "server[\(serverIndex)]"
                for key in server.keys {
                    if !Self.knownServerKeys.contains(key) {
                        warnings.append("Unknown key '\(key)' in server '\(serverUrl)'")
                    }
                }

                // Check topics
                if let topics = server["topics"] as? [[String: Any]] {
                    for (topicIndex, topic) in topics.enumerated() {
                        let topicName = topic["name"] as? String ?? "topic[\(topicIndex)]"
                        for key in topic.keys {
                            if !Self.knownTopicKeys.contains(key) {
                                warnings.append("Unknown key '\(key)' in topic '\(topicName)' (server: \(serverUrl))")
                            }
                        }

                        // Check actions
                        if let actions = topic["actions"] as? [[String: Any]] {
                            for (actionIndex, action) in actions.enumerated() {
                                let actionTitle = action["title"] as? String ?? "action[\(actionIndex)]"
                                for key in action.keys {
                                    if !Self.knownActionKeys.contains(key) {
                                        warnings.append("Unknown key '\(key)' in action '\(actionTitle)' (topic: \(topicName))")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if warnings.isEmpty {
            return nil
        }
        return warnings.joined(separator: "\n")
    }

    /// Validates that the config file has secure permissions (not world-writable)
    private func validateFilePermissions(at path: String) throws {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: path)

        guard let posixPermissions = attributes[.posixPermissions] as? Int else {
            return  // Can't determine permissions, allow
        }

        // Check if world-writable (others have write permission: ----w--w-)
        // POSIX permission bits: owner (rwx), group (rwx), others (rwx)
        // World-writable means the last octet has write bit (0o002)
        let worldWritable = (posixPermissions & 0o002) != 0

        if worldWritable {
            throw ConfigError.insecureFilePermissions(
                "Config file at \(path) is world-writable (permissions: \(String(posixPermissions, radix: 8))). " +
                "Please run: chmod o-w \"\(path)\""
            )
        }
    }

    /// Creates a sample configuration file at the specified path
    static func createSampleConfig(at path: String? = nil) throws {
        let configPath = path ?? defaultConfigPath
        let url = URL(fileURLWithPath: configPath)
        let directory = url.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let sampleYAML = """
        # ntfy-macos configuration file
        servers:
          - url: https://ntfy.sh
            # token: your_token_here  # optional, or use 'ntfy-macos auth add'
            # allowed_schemes:  # optional, defaults to [http, https]
            #   - https
            #   - myapp
            # allowed_domains:  # optional, restrict URLs to specific domains
            #   - example.com
            #   - "*.trusted.org"
            topics:
              - name: alerts
                icon_symbol: bell.fill
                # click_url: false  # disable opening browser on click
                actions:
                  - title: Acknowledge
                    type: script
                    path: /usr/local/bin/ack-alert.sh

              - name: releases
                icon_symbol: arrow.down.circle.fill
                click_url: https://github.com/org/repo/releases  # custom URL on click

          - url: https://your-private-server.com
            token: your_private_token
            topics:
              - name: deployments
                icon_path: /Users/you/icons/deploy.png
                auto_run_script: /usr/local/bin/deploy-handler.sh

              - name: monitoring
                icon_symbol: server.rack
                silent: true
        """

        try sampleYAML.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Retrieves the authentication token for a specific server
    func getAuthToken(forServer serverURL: String) -> String? {
        guard let config = config else { return nil }

        // Find the server config
        guard let serverConfig = config.servers.first(where: { $0.url == serverURL }) else {
            return nil
        }

        // Try Keychain first
        if let keychainToken = try? KeychainHelper.getToken(forServer: serverURL) {
            return keychainToken
        }

        // Fallback to config token
        return serverConfig.token
    }

    /// Finds a topic configuration by name (searches all servers)
    func topicConfig(for topicName: String) -> TopicConfig? {
        return config?.allTopics.first { $0.name == topicName }
    }
}
