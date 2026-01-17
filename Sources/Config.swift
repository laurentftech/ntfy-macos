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

    enum CodingKeys: String, CodingKey {
        case name
        case iconPath = "icon_path"
        case iconSymbol = "icon_symbol"
        case autoRunScript = "auto_run_script"
        case silent
        case clickUrl = "click_url"
        case actions
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
    let webUrl: String?  // Optional URL to open in browser (defaults to url)
    let token: String?
    let topics: [TopicConfig]

    enum CodingKeys: String, CodingKey {
        case url
        case webUrl = "web_url"
        case token
        case topics
    }
}

struct AppConfig: Codable {
    let servers: [ServerConfig]

    // Convenience: all topics across all servers
    var allTopics: [TopicConfig] {
        servers.flatMap { $0.topics }
    }
}

enum ConfigError: Error {
    case fileNotFound
    case invalidYAML(Error)
    case decodingError(Error)
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

        let yamlString: String
        do {
            yamlString = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigError.fileNotFound
        }

        let decoder = YAMLDecoder()
        do {
            let decodedConfig = try decoder.decode(AppConfig.self, from: yamlString)
            lock.lock()
            defer { lock.unlock() }
            self._config = decodedConfig
        } catch {
            throw ConfigError.decodingError(error)
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
            # token: your_token_here  # optional
            # web_url: https://ntfy.sh  # optional: base URL for browser (defaults to url)
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
            web_url: https://ntfy.example.com  # public URL for browser access
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
