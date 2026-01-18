import AppKit

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    var onReloadConfig: (() -> Void)?

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

        let statusMenuItem = NSMenuItem(title: "ntfy-macos running", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu?.addItem(statusMenuItem)

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
        let versionLabel = NSTextField(labelWithString: "Version 0.1.5")
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
        if let item = menu?.items.first {
            item.title = status
        }
    }
}
