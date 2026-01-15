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
    let actions: [NotificationAction]?

    enum CodingKeys: String, CodingKey {
        case name
        case iconPath = "icon_path"
        case iconSymbol = "icon_symbol"
        case autoRunScript = "auto_run_script"
        case silent
        case actions
    }
}

struct AppConfig: Codable {
    let server: String
    let token: String?
    let topics: [TopicConfig]
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
        # Server URL (required)
        server: https://ntfy.sh

        # Authentication token (optional, can also be stored in Keychain)
        # token: your_token_here

        # Topics to subscribe to
        topics:
          - name: alerts
            icon_symbol: bell.fill
            actions:
              - title: Acknowledge
                type: script
                path: /usr/local/bin/ack-alert.sh

          - name: deployments
            icon_path: /Users/you/icons/deploy.png
            auto_run_script: /usr/local/bin/deploy-handler.sh
            silent: false

          - name: monitoring
            icon_symbol: server.rack
            silent: true
            auto_run_script: /usr/local/bin/monitor-handler.sh
        """

        try sampleYAML.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Retrieves the authentication token (Keychain takes priority over YAML)
    func getAuthToken() -> String? {
        guard let config = config else { return nil }

        // Try Keychain first
        if let keychainToken = try? KeychainHelper.getToken(forServer: config.server) {
            return keychainToken
        }

        // Fallback to YAML token
        return config.token
    }

    /// Finds a topic configuration by name
    func topicConfig(for topicName: String) -> TopicConfig? {
        return config?.topics.first { $0.name == topicName }
    }
}
