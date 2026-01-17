import AppKit
import ServiceManagement

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var startAtLoginItem: NSMenuItem?
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

        // Start at Login toggle
        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.isEnabled = true
        loginItem.state = isStartAtLoginEnabled() ? .on : .off
        startAtLoginItem = loginItem
        menu?.addItem(loginItem)

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

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.isEnabled = true
        menu?.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func isStartAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc func toggleStartAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    startAtLoginItem?.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    startAtLoginItem?.state = .on
                }
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        }
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

    func updateStatus(_ status: String) {
        if let item = menu?.items.first {
            item.title = status
        }
    }
}
