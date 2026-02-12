import AppKit

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var statusMenuItem: NSMenuItem?
    private var serversSubmenu: NSMenu?
    private var errorMenuItem: NSMenuItem?
    private var aboutWindow: NSWindow?
    var onReloadConfig: (() -> Void)?

    // Connection tracking
    private var serverStatuses: [String: ServerConnectionStatus] = [:]
    private var connectingAnimationTimer: Timer?
    private var connectingAnimationVisible: Bool = true
    private var currentConfigError: String?

    enum ConnectionState {
        case connecting    // Never connected yet (orange, flashing)
        case connected     // Currently connected (green)
        case disconnected  // Was connected, now lost (red)
    }

    struct ServerConnectionStatus {
        let url: String
        let topics: [String]
        var isConnected: Bool
        var hasEverConnected: Bool  // Track if we've ever successfully connected

        var state: ConnectionState {
            if isConnected {
                return .connected
            } else if hasEverConnected {
                return .disconnected
            } else {
                return .connecting
            }
        }
    }

    static let shared = StatusBarController()

    private override init() {
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            if let image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "ntfy") {
                image.isTemplate = true // Makes it adapt to light/dark mode
                button.image = image
            }
            button.toolTip = "ntfy-macos"
        }

        setupMenu()
    }

    private func setupMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false

        statusMenuItem = NSMenuItem(title: "Connecting...", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        menu?.addItem(statusMenuItem!)

        // Error menu item (hidden by default)
        errorMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        errorMenuItem?.isEnabled = false
        errorMenuItem?.isHidden = true
        menu?.addItem(errorMenuItem!)

        // Servers submenu showing individual server statuses
        let serversItem = NSMenuItem(title: "Servers", action: nil, keyEquivalent: "")
        serversSubmenu = NSMenu()
        serversItem.submenu = serversSubmenu
        menu?.addItem(serversItem)

        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu?.addItem(settingsItem)

        let showConfigItem = NSMenuItem(title: "Show Config in Finder", action: #selector(showConfigInFinder), keyEquivalent: "")
        showConfigItem.target = self
        showConfigItem.isEnabled = true
        menu?.addItem(showConfigItem)

        let reloadConfigItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reloadConfigItem.target = self
        reloadConfigItem.isEnabled = true
        menu?.addItem(reloadConfigItem)

        menu?.addItem(NSMenuItem.separator())

        let viewLogsItem = NSMenuItem(title: "View Logs...", action: #selector(viewLogs), keyEquivalent: "l")
        viewLogsItem.target = self
        viewLogsItem.isEnabled = true
        menu?.addItem(viewLogsItem)

        menu?.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About ntfy-macos", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.isEnabled = true
        menu?.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.isEnabled = true
        menu?.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc func showConfigInFinder() {
        let configPath = NSString(string: "~/.config/ntfy-macos").expandingTildeInPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configPath)
    }

    @objc func reloadConfig() {
        onReloadConfig?()
    }

    @objc func viewLogs() {
        // All logs now go to the same location with rotation
        if FileManager.default.fileExists(atPath: Log.logFilePath) {
            NSWorkspace.shared.selectFile(Log.logFilePath, inFileViewerRootedAtPath: Log.logDirectory)
            return
        }

        // No logs found
        let alert = NSAlert()
        alert.messageText = "Logs Not Found"
        alert.informativeText = "No log files found yet. Logs will be created in \(Log.logDirectory)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        // Re-apply accessory policy to prevent Dock icon from lingering
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func openServerURL(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func showAbout() {
        // Reuse existing window if already open
        if let existingWindow = aboutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About ntfy-macos"
        window.center()
        window.isReleasedWhenClosed = false  // Keep window object alive after closing

        let contentView = NSView(frame: window.contentView!.bounds)

        // Title
        let titleLabel = NSTextField(labelWithString: "ntfy-macos")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 20, y: 155, width: 300, height: 25)
        contentView.addSubview(titleLabel)

        // Version
        let versionLabel = NSTextField(labelWithString: "Version \(AppConstants.effectiveVersion)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 20, y: 135, width: 300, height: 18)
        contentView.addSubview(versionLabel)

        // Description with clickable links
        let textView = NSTextView(frame: NSRect(x: 17, y: 45, width: 306, height: 85))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false

        let attributedString = NSMutableAttributedString()
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let linkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        attributedString.append(NSAttributedString(string: "Native macOS client for ntfy.sh\n\n", attributes: normalAttrs))
        attributedString.append(NSAttributedString(string: "Created by ", attributes: normalAttrs))

        let authorLink = NSMutableAttributedString(string: "Laurent FRANCOISE", attributes: linkAttrs)
        authorLink.addAttribute(.link, value: "https://laurentftech.github.io", range: NSRange(location: 0, length: authorLink.length))
        attributedString.append(authorLink)

        attributedString.append(NSAttributedString(string: "\n", attributes: normalAttrs))

        let githubLink = NSMutableAttributedString(string: "ntfy-macos on GitHub", attributes: linkAttrs)
        githubLink.addAttribute(.link, value: "https://github.com/laurentftech/ntfy-macos", range: NSRange(location: 0, length: githubLink.length))
        attributedString.append(githubLink)

        attributedString.append(NSAttributedString(string: "\n\nPowered by ", attributes: normalAttrs))

        let ntfyLink = NSMutableAttributedString(string: "ntfy", attributes: linkAttrs)
        ntfyLink.addAttribute(.link, value: "https://ntfy.sh", range: NSRange(location: 0, length: ntfyLink.length))
        attributedString.append(ntfyLink)

        attributedString.append(NSAttributedString(string: " by Philipp C. Heckel", attributes: normalAttrs))

        textView.textStorage?.setAttributedString(attributedString)
        contentView.addSubview(textView)

        // License
        let licenseLabel = NSTextField(labelWithString: "Licensed under MIT")
        licenseLabel.font = NSFont.systemFont(ofSize: 11)
        licenseLabel.textColor = .tertiaryLabelColor
        licenseLabel.frame = NSRect(x: 20, y: 15, width: 300, height: 16)
        contentView.addSubview(licenseLabel)

        window.contentView = contentView
        aboutWindow = window  // Store reference to prevent deallocation
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Ensure we revert to accessory mode when the About window is closed
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                _ = NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func updateStatus(_ status: String) {
        statusMenuItem?.title = status
    }

    /// Shows a configuration error in the menu (in red)
    func showConfigError(_ error: String) {
        currentConfigError = error
        errorMenuItem?.isHidden = false

        // Create attributed string with red color
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.systemFont(ofSize: 13)
        ]
        let attributedTitle = NSAttributedString(string: "⚠️ Config Error", attributes: attributes)
        errorMenuItem?.attributedTitle = attributedTitle
        errorMenuItem?.toolTip = error
    }

    /// Shows a configuration warning in the menu (in orange)
    func showConfigWarning(_ warning: String) {
        currentConfigError = warning
        errorMenuItem?.isHidden = false

        // Create attributed string with orange color
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemOrange,
            .font: NSFont.systemFont(ofSize: 13)
        ]
        let attributedTitle = NSAttributedString(string: "⚠️ Config Warning", attributes: attributes)
        errorMenuItem?.attributedTitle = attributedTitle
        errorMenuItem?.toolTip = warning
    }

    /// Clears any config error/warning from the menu
    func clearConfigError() {
        currentConfigError = nil
        errorMenuItem?.isHidden = true
        errorMenuItem?.attributedTitle = nil
        errorMenuItem?.toolTip = nil
    }

    /// Initialize server tracking from config
    func initializeServers(servers: [(url: String, topics: [String])]) {
        stopConnectingAnimation()
        serverStatuses.removeAll()
        for server in servers {
            serverStatuses[server.url] = ServerConnectionStatus(
                url: server.url,
                topics: server.topics,
                isConnected: false,
                hasEverConnected: false
            )
        }
        refreshServersSubmenu()
        refreshMainStatus()
        startConnectingAnimationIfNeeded()
    }

    /// Update connection status for a specific server
    func setServerConnected(_ serverUrl: String, connected: Bool) {
        if var status = serverStatuses[serverUrl] {
            status.isConnected = connected
            if connected {
                status.hasEverConnected = true
            }
            serverStatuses[serverUrl] = status
            refreshServersSubmenu()
            refreshMainStatus()
            updateConnectingAnimation()
        }
    }

    // MARK: - Connecting Animation

    private func startConnectingAnimationIfNeeded() {
        let hasConnectingServers = serverStatuses.values.contains { $0.state == .connecting }
        if hasConnectingServers && connectingAnimationTimer == nil {
            connectingAnimationVisible = true
            connectingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.toggleConnectingAnimation()
                }
            }
        }
    }

    private func stopConnectingAnimation() {
        connectingAnimationTimer?.invalidate()
        connectingAnimationTimer = nil
        connectingAnimationVisible = true
    }

    private func updateConnectingAnimation() {
        let hasConnectingServers = serverStatuses.values.contains { $0.state == .connecting }
        if hasConnectingServers {
            startConnectingAnimationIfNeeded()
        } else {
            stopConnectingAnimation()
        }
    }

    private func toggleConnectingAnimation() {
        connectingAnimationVisible.toggle()
        refreshMainStatus()
        refreshServersSubmenu()
    }

    private func refreshMainStatus() {
        let totalServers = serverStatuses.count
        let connectedServers = serverStatuses.values.filter { $0.state == .connected }.count
        let connectingServers = serverStatuses.values.filter { $0.state == .connecting }.count
        let disconnectedServers = serverStatuses.values.filter { $0.state == .disconnected }.count
        let totalTopics = serverStatuses.values.flatMap { $0.topics }.count

        let attributedTitle = NSMutableAttributedString()
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13)
        ]

        if totalServers == 0 {
            statusMenuItem?.attributedTitle = NSAttributedString(
                string: "No servers configured",
                attributes: textAttrs
            )
        } else if connectedServers == totalServers {
            // Green indicator for all connected
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.systemGreen,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: "● ", attributes: statusAttrs))

            let topicText = totalTopics == 1 ? "topic" : "topics"
            let serverText = totalServers == 1 ? "server" : "servers"
            attributedTitle.append(NSAttributedString(
                string: "\(totalTopics) \(topicText) on \(totalServers) \(serverText)",
                attributes: textAttrs
            ))
            statusMenuItem?.attributedTitle = attributedTitle
        } else if connectingServers > 0 && disconnectedServers == 0 && connectedServers == 0 {
            // All servers are still connecting (flashing orange)
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: connectingAnimationVisible ? NSColor.systemOrange : NSColor.clear,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: "● ", attributes: statusAttrs))
            attributedTitle.append(NSAttributedString(string: "Connecting...", attributes: textAttrs))
            statusMenuItem?.attributedTitle = attributedTitle
        } else if disconnectedServers > 0 {
            // Some servers disconnected (red indicator)
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: "● ", attributes: statusAttrs))
            attributedTitle.append(NSAttributedString(
                string: "\(connectedServers)/\(totalServers) servers connected",
                attributes: textAttrs
            ))
            statusMenuItem?.attributedTitle = attributedTitle
        } else {
            // Mixed state: some connected, some connecting (orange)
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: connectingAnimationVisible ? NSColor.systemOrange : NSColor.clear,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: "● ", attributes: statusAttrs))
            attributedTitle.append(NSAttributedString(
                string: "\(connectedServers)/\(totalServers) servers connected",
                attributes: textAttrs
            ))
            statusMenuItem?.attributedTitle = attributedTitle
        }
    }

    private func refreshServersSubmenu() {
        serversSubmenu?.removeAllItems()

        if serverStatuses.isEmpty {
            let noServersItem = NSMenuItem(title: "No servers configured", action: nil, keyEquivalent: "")
            noServersItem.isEnabled = false
            serversSubmenu?.addItem(noServersItem)
            return
        }

        for (_, status) in serverStatuses.sorted(by: { $0.key < $1.key }) {
            let topicsText = status.topics.joined(separator: ", ")

            // Create attributed string with colored status indicator
            let serverItem = NSMenuItem(title: "", action: #selector(openServerURL(_:)), keyEquivalent: "")
            serverItem.target = self
            serverItem.representedObject = status.url

            let attributedTitle = NSMutableAttributedString()

            // Status indicator with color based on connection state
            let statusIcon: String
            let statusColor: NSColor

            switch status.state {
            case .connected:
                statusIcon = "●"
                statusColor = NSColor.systemGreen
            case .disconnected:
                statusIcon = "●"
                statusColor = NSColor.systemRed
            case .connecting:
                statusIcon = "●"
                // Flashing effect for connecting
                statusColor = connectingAnimationVisible ? NSColor.systemOrange : NSColor.clear
            }

            let statusAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: statusColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: "\(statusIcon) ", attributes: statusAttrs))

            // Server URL in normal color
            let urlAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            attributedTitle.append(NSAttributedString(string: status.url, attributes: urlAttrs))

            serverItem.attributedTitle = attributedTitle

            // Add tooltip with topics and state
            let stateText: String
            switch status.state {
            case .connected: stateText = "Connected"
            case .disconnected: stateText = "Disconnected"
            case .connecting: stateText = "Connecting..."
            }
            serverItem.toolTip = "\(stateText)\nTopics: \(topicsText)"

            serversSubmenu?.addItem(serverItem)

            // Add topics as indented subitems
            for topic in status.topics {
                let topicItem = NSMenuItem(title: "    \(topic)", action: nil, keyEquivalent: "")
                topicItem.isEnabled = false
                topicItem.indentationLevel = 1
                serversSubmenu?.addItem(topicItem)
            }
        }
    }
}
