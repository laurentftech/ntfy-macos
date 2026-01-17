import Foundation
import UserNotifications
import AppKit

/// App constants - used when running via symlink where Bundle.main.bundleIdentifier is nil
enum AppConstants {
    static let bundleIdentifier = "com.laurentftech.ntfy-macos"

    /// Returns the bundle identifier, falling back to hardcoded value if running via symlink
    static var effectiveBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? bundleIdentifier
    }
}

final class NtfyMacOS: NtfyClientDelegate, @unchecked Sendable {
    private var clients: [NtfyClient] = []
    private var notificationManager: NotificationManager?
    private let scriptRunner = ScriptRunner()
    private var configWatcher: ConfigWatcher?

    init() {
        // Don't initialize notificationManager here - wait until it's needed
    }

    private func ensureNotificationManager() -> NotificationManager {
        if notificationManager == nil {
            notificationManager = NotificationManager.shared
            notificationManager?.setScriptRunner(scriptRunner)
        }
        return notificationManager!
    }

    func serve(configPath: String? = nil) {
        print("Starting ntfy-macos service...")
        fflush(stdout)

        do {
            try ConfigManager.shared.loadConfig(from: configPath)
        } catch ConfigError.fileNotFound {
            print("Configuration file not found.")
            print("Creating sample configuration at \(ConfigManager.defaultConfigPath)")
            do {
                try ConfigManager.createSampleConfig()
                print("Sample configuration created. Please edit it and restart the service.")
                exit(1)
            } catch {
                print("Failed to create sample configuration: \(error)")
                exit(1)
            }
        } catch {
            print("Failed to load configuration: \(error)")
            exit(1)
        }

        guard let config = ConfigManager.shared.config else {
            print("Configuration is invalid")
            exit(1)
        }

        let allTopics = config.allTopics.map { $0.name }
        guard !allTopics.isEmpty else {
            print("No topics configured")
            exit(1)
        }

        print("Configured servers: \(config.servers.count)")
        for server in config.servers {
            let topics = server.topics.map { $0.name }.joined(separator: ", ")
            print("  - \(server.url): \(topics)")
        }
        fflush(stdout)

        // Start watching config file for changes
        configWatcher = ConfigWatcher(configPath: configPath)
        configWatcher?.startWatching { [weak self] in
            self?.reloadConfig()
        }
    }

    func startService() {
        guard ConfigManager.shared.config != nil else {
            print("Configuration is invalid")
            fflush(stdout)
            return
        }

        let notificationManager = ensureNotificationManager()

        // Check authorization status before starting the service
        notificationManager.getAuthorizationStatus { [weak self] status in
            guard let self = self else { return }

            print("Authorization status: \(status.rawValue)")
            fflush(stdout)

            if status == .authorized {
                self.connectClients()
            } else {
                // Request permission automatically on first launch
                print("Requesting notification permission...")
                fflush(stdout)
                Task { @MainActor in
                    PermissionHelper.requestPermissionsWithWindow { granted in
                        if granted {
                            print("✅ Permission granted!")
                            fflush(stdout)
                            self.connectClients()
                        } else {
                            print("❌ Notification permission not granted")
                            print("   Please enable notifications in System Settings → Notifications → ntfy-macos")
                            fflush(stdout)
                            exit(1)
                        }
                    }
                }
            }
        }
    }

    private func connectClients() {
        guard let config = ConfigManager.shared.config else { return }

        // Create a client for each server
        for serverConfig in config.servers {
            let topicNames = serverConfig.topics.map { $0.name }
            guard !topicNames.isEmpty else { continue }

            print("Creating client for \(serverConfig.url)...")
            fflush(stdout)

            let authToken = ConfigManager.shared.getAuthToken(forServer: serverConfig.url)
            let client = NtfyClient(
                serverURL: serverConfig.url,
                topics: topicNames,
                authToken: authToken
            )
            client.delegate = self
            self.clients.append(client)

            print("Connecting to \(serverConfig.url)...")
            fflush(stdout)
            client.connect()
        }
    }

    func reloadConfig() {
        print("Reloading configuration...")
        fflush(stdout)

        // Disconnect all clients
        for client in clients {
            client.disconnect()
        }
        clients.removeAll()

        // Reload config file
        do {
            try ConfigManager.shared.loadConfig(from: nil)
        } catch {
            print("Failed to reload configuration: \(error)")
            fflush(stdout)
            return
        }

        guard let config = ConfigManager.shared.config else {
            print("Configuration is invalid")
            fflush(stdout)
            return
        }

        print("Reloaded servers: \(config.servers.count)")
        for server in config.servers {
            let topics = server.topics.map { $0.name }.joined(separator: ", ")
            print("  - \(server.url): \(topics)")
        }
        fflush(stdout)

        // Reconnect with new config
        startService()
    }

    func ntfyClient(_ client: NtfyClient, didReceiveMessage message: NtfyMessage) {
        print("📩 Received message on topic '\(message.topic)': \(message.message ?? "")")
        fflush(stdout)

        let topicConfig = ConfigManager.shared.topicConfig(for: message.topic)

        // Handle auto-run scripts
        if let autoRunScript = topicConfig?.autoRunScript {
            if scriptRunner.validateScript(at: autoRunScript) {
                print("Auto-running script: \(autoRunScript)")
                scriptRunner.runScript(at: autoRunScript, withArgument: message.message)
            }
        }

        // Show notification (respects silent flag)
        ensureNotificationManager().showNotification(for: message, topicConfig: topicConfig)
    }

    func ntfyClient(_ client: NtfyClient, didEncounterError error: Error) {
        print("Error: \(error.localizedDescription)")
    }

    func ntfyClientDidConnect(_ client: NtfyClient) {
        print("Successfully connected to ntfy server")
    }

    func ntfyClientDidDisconnect(_ client: NtfyClient) {
        print("Disconnected from ntfy server")
    }
}

struct CLI {
    // Keep a strong reference to prevent deallocation
    @MainActor
    static var ntfyAppInstance: NtfyMacOS?

    @MainActor
    static func main() -> Bool {
        let arguments = CommandLine.arguments

        // When launched without arguments (e.g., via double-click or `open`),
        // start serve mode directly
        if arguments.count < 2 {
            print("🚀 Starting ntfy-macos service...")
            ntfyAppInstance = NtfyMacOS()
            ntfyAppInstance?.serve(configPath: nil)

            guard ConfigManager.shared.config != nil else {
                print("Configuration is invalid. Run 'ntfy-macos serve' to create a sample config.")
                return false
            }

            // Schedule the actual service start for after RunLoop begins
            // Use Timer to ensure RunLoop is actively running
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [ntfyAppInstance] _ in
                ntfyAppInstance?.startService()
            }

            return true // Needs RunLoop
        }

        let command = arguments[1]

        switch command {
        case "serve":
            let configPath = getFlag(arguments: arguments, flag: "--config")
            ntfyAppInstance = NtfyMacOS()
            ntfyAppInstance?.serve(configPath: configPath)

            // Extract config for later use
            guard ConfigManager.shared.config != nil else {
                print("Configuration is invalid")
                exit(1)
            }

            // Schedule the actual service start for after RunLoop begins
            // Use Timer to ensure RunLoop is actively running
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [ntfyAppInstance] _ in
                ntfyAppInstance?.startService()
            }

            return true // Needs RunLoop

        case "auth":
            handleAuth(arguments: arguments)
            return false

        case "test-notify":
            handleTestNotify(arguments: arguments)
            return true // Needs RunLoop

        case "init":
            handleInit(arguments: arguments)
            return false

        case "help", "--help", "-h":
            printUsage()
            exit(0)

        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }

    static func handleAuth(arguments: [String]) {
        // Check for subcommand: add, list, remove
        guard arguments.count >= 3 else {
            printAuthUsage()
            exit(1)
        }

        let subcommand = arguments[2]

        switch subcommand {
        case "add":
            // ntfy-macos auth add <server-url> <token>
            guard arguments.count >= 5 else {
                print("Usage: ntfy-macos auth add <server-url> <token>")
                exit(1)
            }
            let server = arguments[3]
            let token = arguments[4]

            do {
                try KeychainHelper.saveToken(token, forServer: server)
                print("✅ Token saved for server: \(server)")
            } catch {
                print("❌ Failed to save token: \(error)")
                exit(1)
            }

        case "list":
            // ntfy-macos auth list
            do {
                let servers = try KeychainHelper.listServers()
                if servers.isEmpty {
                    print("No tokens stored in Keychain.")
                } else {
                    print("Stored tokens for servers:")
                    for server in servers {
                        print("  • \(server)")
                    }
                }
            } catch {
                print("❌ Failed to list servers: \(error)")
                exit(1)
            }

        case "remove":
            // ntfy-macos auth remove <server-url>
            guard arguments.count >= 4 else {
                print("Usage: ntfy-macos auth remove <server-url>")
                exit(1)
            }
            let server = arguments[3]

            do {
                try KeychainHelper.deleteToken(forServer: server)
                print("✅ Token removed for server: \(server)")
            } catch {
                print("❌ Failed to remove token: \(error)")
                exit(1)
            }

        default:
            print("Unknown auth subcommand: \(subcommand)")
            printAuthUsage()
            exit(1)
        }
    }

    static func printAuthUsage() {
        print("""
        Usage: ntfy-macos auth <subcommand>

        Subcommands:
            add <server-url> <token>    Store a token in Keychain
            list                        List all servers with stored tokens
            remove <server-url>         Remove a token from Keychain

        Examples:
            ntfy-macos auth add https://ntfy.sh tk_mytoken
            ntfy-macos auth list
            ntfy-macos auth remove https://ntfy.sh
        """)
    }

    @MainActor
    static func handleTestNotify(arguments: [String]) {
        guard let topic = getFlag(arguments: arguments, flag: "--topic") else {
            print("Usage: ntfy-macos test-notify --topic <NAME>")
            exit(1)
        }

        print("🚀 Requesting notification permissions with GUI window...")

        PermissionHelper.requestPermissionsWithWindow { granted in
            Task { @MainActor in
                if granted {
                    let notificationManager = NotificationManager.shared
                    notificationManager.showTestNotification(topic: topic)
                    print("✅ Test notification sent for topic: \(topic)")
                    // Give time for notification to be delivered, then exit cleanly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NSApp.terminate(nil)
                    }
                } else {
                    print("❌ Notification permission denied")
                    print("")
                    print("💡 The app should now appear in System Settings → Notifications")
                    print("   Please enable notifications there and try again.")
                    NSApp.terminate(nil)
                }
            }
        }

        // Don't call RunLoop here - it's managed by the entry point
    }

    static func handleInit(arguments: [String]) {
        let configPath = getFlag(arguments: arguments, flag: "--path") ?? ConfigManager.defaultConfigPath

        do {
            try ConfigManager.createSampleConfig(at: configPath)
            print("Sample configuration created at: \(configPath)")
            print("Please edit the configuration file and run 'ntfy-macos serve' to start the service.")
        } catch {
            print("Failed to create configuration: \(error)")
            exit(1)
        }
    }

    static func getFlag(arguments: [String], flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    static func printUsage() {
        print("""
        ntfy-macos - Native macOS CLI Notifier & Automation Agent

        USAGE:
            ntfy-macos <COMMAND> [OPTIONS]

        COMMANDS:
            serve                    Start the notification service
                --config <PATH>      Optional: Custom configuration file path

            auth <subcommand>        Manage authentication tokens in Keychain
                add <url> <token>    Store a token for a server
                list                 List all servers with stored tokens
                remove <url>         Remove a token for a server

            test-notify              Send a test notification
                --topic <NAME>       Topic name to test

            init                     Create a sample configuration file
                --path <PATH>        Optional: Custom path for config file

            help                     Show this help message

        EXAMPLES:
            # Create configuration
            ntfy-macos init

            # Store authentication token in Keychain
            ntfy-macos auth add https://ntfy.sh tk_mytoken

            # List stored tokens
            ntfy-macos auth list

            # Remove a token
            ntfy-macos auth remove https://ntfy.sh

            # Start the service
            ntfy-macos serve

            # Test notifications
            ntfy-macos test-notify --topic alerts

        CONFIGURATION:
            Default config location: ~/.config/ntfy-macos/config.yml

            Tokens can be stored either:
            - In the config file (token: field under each server)
            - In the Keychain (using 'auth add' command) - more secure

        For more information, visit: https://github.com/laurentftech/ntfy-macos
        """)
    }
}

// App delegate to disable state restoration (prevents crashes from corrupted saved state)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldRestoreSecureUntitleableWindows(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Unregister from launchctl to allow clean restart via brew services
        // This silently fails if not launched via brew services, which is fine
        let uid = getuid()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(uid)/homebrew.mxcl.ntfy-macos"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }
}

// Entry point - Initialize NSApplication for proper macOS app behavior
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate

// Schedule CLI execution after the run loop starts to ensure AppKit is fully initialized
// This fixes the frozen window issue where events weren't being processed
DispatchQueue.main.async {
    let needsRunLoop = CLI.main()
    if !needsRunLoop {
        // Commands that don't need the run loop can exit immediately
        NSApp.terminate(nil)
    } else {
        // For serve command: use accessory mode (menu bar only, no Dock icon)
        app.setActivationPolicy(.accessory)
        StatusBarController.shared.setup()
        StatusBarController.shared.onReloadConfig = {
            CLI.ntfyAppInstance?.reloadConfig()
        }
    }
}

// Start the run loop - this properly initializes AppKit and processes events
app.run()
