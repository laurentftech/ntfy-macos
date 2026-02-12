import Foundation
import AppKit
import UserNotifications

/// Helper to show a window that makes notification permission dialogs appear
@MainActor
class PermissionHelper {
    private static var window: NSWindow?
    private static var completion: ((Bool) -> Void)?
    private static var label: NSTextField?

    static func requestPermissionsWithWindow(completion: @escaping @Sendable (Bool) -> Void) {
        // First check if already authorized - if so, skip the window entirely
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                if status == .authorized {
                    completion(true)
                    return
                }
                // Not authorized yet, show the window
                self.showPermissionWindow(completion: completion)
            }
        }
    }

    private static func showPermissionWindow(completion: @escaping @Sendable (Bool) -> Void) {
        self.completion = completion

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.window = window

        window.title = "ntfy-macos - Notification Setup"
        window.center()

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let label = NSTextField(wrappingLabelWithString: "Checking notification permissions...")
        label.frame = NSRect(x: 30, y: 120, width: 440, height: 80)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 14)
        self.label = label
        contentView.addSubview(label)

        let button = NSButton(frame: NSRect(x: 175, y: 40, width: 150, height: 40))
        button.title = "Request Permission"
        button.bezelStyle = .rounded
        button.target = PermissionHelperTarget.shared
        button.action = #selector(PermissionHelperTarget.requestPermissionClicked)
        button.isEnabled = false
        contentView.addSubview(button)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Check current status after a brief delay to let the window appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkAndUpdateUI(button: button)
        }
    }

    private static func checkAndUpdateUI(button: NSButton) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                switch status {
                case .notDetermined:
                    self.label?.stringValue = "ntfy-macos needs permission to send notifications.\n\nClick the button below to request permission."
                    button.isEnabled = true

                case .authorized:
                    // This shouldn't happen since we check before showing the window
                    self.finish(granted: true)

                case .denied:
                    self.label?.stringValue = "⚠️ Notifications are denied.\n\nPlease enable in System Settings → Notifications → ntfy-macos"
                    button.title = "Open System Settings"
                    button.isEnabled = true
                    button.action = #selector(PermissionHelperTarget.openSettings)

                default:
                    self.label?.stringValue = "⚠️ Notification status: \(status.rawValue)"
                    button.isHidden = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.finish(granted: false)
                    }
                }
            }
        }
    }

    static func requestPermission() {
        label?.stringValue = "Requesting permission..."

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Permission error: \(error)")
                    self.label?.stringValue = "Error: \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.finish(granted: false)
                    }
                } else if granted {
                    print("✅ Permission granted!")
                    self.label?.stringValue = "✅ Permission granted!\n\nNotifications are now enabled."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.finish(granted: true)
                    }
                } else {
                    print("❌ Permission denied")
                    self.label?.stringValue = "❌ Permission denied.\n\nYou can enable notifications in System Settings."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.finish(granted: false)
                    }
                }
            }
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            finish(granted: false)
        }
    }

    static func finish(granted: Bool) {
        let callback = completion
        completion = nil
        window?.close()
        window = nil
        label = nil
        // Re-apply accessory policy to prevent Dock icon from lingering
        NSApp.setActivationPolicy(.accessory)
        callback?(granted)
    }
}

// Separate target class to handle button actions (avoids @objc issues with static methods)
@MainActor
class PermissionHelperTarget: NSObject {
    static let shared = PermissionHelperTarget()

    private override init() {
        super.init()
    }

    @objc func requestPermissionClicked() {
        Task { @MainActor in
            PermissionHelper.requestPermission()
        }
    }

    @objc func openSettings() {
        Task { @MainActor in
            PermissionHelper.openSystemSettings()
        }
    }
}
