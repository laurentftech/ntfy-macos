import AppKit

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var statusMenuItem: NSMenuItem?
    private var serversSubmenu: NSMenu?
    var onReloadConfig: (() -> Void)?

    // Connection tracking
    private var serverStatuses: [String: ServerConnectionStatus] = [:]

    struct ServerConnectionStatus {
        let url: String
        let topics: [String]
        var isConnected: Bool
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

        // Servers submenu showing individual server statuses
        let serversItem = NSMenuItem(title: "Servers", action: nil, keyEquivalent: "")
        serversSubmenu = NSMenu()
        serversItem.submenu = serversSubmenu
        menu?.addItem(serversItem)

        menu?.addItem(NSMenuItem.separator())

        let editConfigItem = NSMenuItem(title: "Edit Config...", action: #selector(editConfig), keyEquivalent: ",")
        editConfigItem.target = self
        editConfigItem.isEnabled = true
        menu?.addItem(editConfigItem)

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

    @objc func editConfig() {
        let configPath = NSString(string: "~/.config/ntfy-macos/config.yml").expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
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
    }

    @objc func showAbout() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About ntfy-macos"
        window.center()

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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateStatus(_ status: String) {
        statusMenuItem?.title = status
    }

    /// Initialize server tracking from config
    func initializeServers(servers: [(url: String, topics: [String])]) {
        serverStatuses.removeAll()
        for server in servers {
            serverStatuses[server.url] = ServerConnectionStatus(
                url: server.url,
                topics: server.topics,
                isConnected: false
            )
        }
        refreshServersSubmenu()
        refreshMainStatus()
    }

    /// Update connection status for a specific server
    func setServerConnected(_ serverUrl: String, connected: Bool) {
        if var status = serverStatuses[serverUrl] {
            status.isConnected = connected
            serverStatuses[serverUrl] = status
            refreshServersSubmenu()
            refreshMainStatus()
        }
    }

    private func refreshMainStatus() {
        let totalServers = serverStatuses.count
        let connectedServers = serverStatuses.values.filter { $0.isConnected }.count
        let totalTopics = serverStatuses.values.flatMap { $0.topics }.count

        if totalServers == 0 {
            statusMenuItem?.title = "No servers configured"
        } else if connectedServers == totalServers {
            let topicText = totalTopics == 1 ? "topic" : "topics"
            let serverText = totalServers == 1 ? "server" : "servers"
            statusMenuItem?.title = "\(totalTopics) \(topicText) on \(totalServers) \(serverText)"
        } else if connectedServers == 0 {
            statusMenuItem?.title = "Connecting..."
        } else {
            statusMenuItem?.title = "\(connectedServers)/\(totalServers) servers connected"
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
            let statusIcon = status.isConnected ? "✓" : "○"
            let topicsText = status.topics.joined(separator: ", ")
            let title = "\(statusIcon) \(status.url)"

            let serverItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            serverItem.isEnabled = false

            // Add tooltip with topics
            serverItem.toolTip = "Topics: \(topicsText)"

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
