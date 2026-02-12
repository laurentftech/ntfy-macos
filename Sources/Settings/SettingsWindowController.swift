import AppKit
import SwiftUI

@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var viewModel: SettingsViewModel?

    private init() {}

    func showSettings() {
        // Reuse existing window if visible
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = SettingsViewModel()
        vm.loadFromConfig()
        self.viewModel = vm

        let settingsView = SettingsView(viewModel: vm)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ntfy-macos Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 650, height: 450)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Revert to accessory mode when window closes
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
}
