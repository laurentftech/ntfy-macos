import Foundation
import UserNotifications
import AppKit

final class NtfyMacOS: NtfyClientDelegate, @unchecked Sendable {
    private var client: NtfyClient?
    private var notificationManager: NotificationManager?
    private let scriptRunner = ScriptRunner()

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

        let topicNames = config.topics.map { $0.name }
        guard !topicNames.isEmpty else {
            print("No topics configured")
            exit(1)
        }

        print("Configured topics: \(topicNames.joined(separator: ", "))")
        fflush(stdout)

        // Don't call RunLoop here - it's managed by the entry point
    }

    func startService(server: String, topicNames: [String]) {
        print("Starting service for server: \(server)")
        fflush(stdout)

        let notificationManager = ensureNotificationManager()

        // Check authorization status before starting the service
        notificationManager.getAuthorizationStatus { status in
            print("Authorization status: \(status.rawValue)")
            fflush(stdout)

            guard status == .authorized else {
                print("❌ Notification permission not granted")
                print("   Please run 'ntfy-macos test-notify' to grant permissions.")
                fflush(stdout)
                exit(1)
            }

            // This should be called after RunLoop has started
            print("Creating NtfyClient...")
            fflush(stdout)

            let authToken = ConfigManager.shared.getAuthToken()
            self.client = NtfyClient(
                serverURL: server,
                topics: topicNames,
                authToken: authToken
            )
            self.client?.delegate = self
            print("Calling connect()...")
            fflush(stdout)
            self.client?.connect()
        }
    }

    func reloadConfig() {
        print("Reloading configuration...")
        fflush(stdout)

        // Disconnect current client
        client?.disconnect()
        client = nil

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

        let topicNames = config.topics.map { $0.name }
        print("Reloaded topics: \(topicNames.joined(separator: ", "))")
        fflush(stdout)

        // Reconnect with new config
        startService(server: config.server, topicNames: topicNames)
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

            guard let config = ConfigManager.shared.config else {
                print("Configuration is invalid. Run 'ntfy-macos serve' to create a sample config.")
                return false
            }
            let topicNames = config.topics.map { $0.name }

            let server = config.server
            // Start service directly - the DispatchQueue.main.async in entry point handles timing
            ntfyAppInstance?.startService(server: server, topicNames: topicNames)
            print("Service started, returning true")
            fflush(stdout)
            return true // Needs RunLoop
        }

        let command = arguments[1]

        switch command {
        case "serve":
            let configPath = getFlag(arguments: arguments, flag: "--config")
            ntfyAppInstance = NtfyMacOS()
            ntfyAppInstance?.serve(configPath: configPath)

            // Extract config for later use
            guard let config = ConfigManager.shared.config else {
                print("Configuration is invalid")
                exit(1)
            }
            let topicNames = config.topics.map { $0.name }

            // Schedule the actual service start for after RunLoop begins
            // Use Timer to ensure RunLoop is actively running
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [ntfyAppInstance] _ in
                ntfyAppInstance?.startService(server: config.server, topicNames: topicNames)
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
        guard let server = getFlag(arguments: arguments, flag: "--server"),
              let token = getFlag(arguments: arguments, flag: "--token") else {
            print("Usage: ntfy-macos auth --server <URL> --token <TOKEN>")
            exit(1)
        }

        do {
            try KeychainHelper.saveToken(token, forServer: server)
            print("Token saved successfully for server: \(server)")
        } catch {
            print("Failed to save token: \(error)")
            exit(1)
        }
    }

    @MainActor
    static func handleTestNotify(arguments: [String]) {
        guard let topic = getFlag(arguments: arguments, flag: "--topic") else {
            print("Usage: ntfy-macos test-notify --topic <NAME>")
            exit(1)
        }

        print("🚀 Requesting notification permissions with GUI window...")

        PermissionHelper.requestPermissionsWithWindow { granted in
            if granted {
                let notificationManager = NotificationManager.shared
                notificationManager.showTestNotification(topic: topic)
                print("✅ Test notification sent for topic: \(topic)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    exit(0)
                }
            } else {
                print("❌ Notification permission denied")
                print("")
                print("💡 The app should now appear in System Settings → Notifications")
                print("   Please enable notifications there and try again.")
                exit(1)
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

            auth                     Store authentication token in Keychain
                --server <URL>       Server URL (e.g., https://ntfy.sh)
                --token <TOKEN>      Authentication token

            test-notify              Send a test notification
                --topic <NAME>       Topic name to test

            init                     Create a sample configuration file
                --path <PATH>        Optional: Custom path for config file

            help                     Show this help message

        EXAMPLES:
            # Create configuration
            ntfy-macos init

            # Store authentication token
            ntfy-macos auth --server https://ntfy.sh --token tk_mytoken

            # Start the service
            ntfy-macos serve

            # Test notifications
            ntfy-macos test-notify --topic alerts

        CONFIGURATION:
            Default config location: ~/.config/ntfy-macos/config.yml

        For more information, visit: https://github.com/laurentftech/ntfy-macos
        """)
    }
}

// Entry point - Initialize NSApplication for proper macOS app behavior
let app = NSApplication.shared

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
