import XCTest
import AppKit
@testable import ntfy_macos

final class NotificationManagerTests: XCTestCase {
    /// The notification center moves the attachment file when the notification is
    /// added, so it must still exist after the attachment is created
    func testCreateAttachmentKeepsFileForDelivery() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()

        let attachment = try XCTUnwrap(NotificationManager.shared.createAttachment(from: image))
        defer { try? FileManager.default.removeItem(at: attachment.url) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachment.url.path))
    }

    // MARK: - NotificationStyle

    private func style(_ priority: Int?, routine: NotificationSoundSetting = .glass, high: NotificationSoundSetting = .critical) -> NotificationStyle {
        NotificationStyle.resolve(priority: priority, routineSound: routine, highSound: high)
    }

    func testLowPrioritiesArePassiveAndSilent() {
        for priority in [1, 2] {
            let result = style(priority, high: .sosumi)
            XCTAssertEqual(result.interruptionLevel, .passive, "priority \(priority)")
            XCTAssertEqual(result.sound, .silent, "priority \(priority)")
        }
    }

    func testDefaultPriorityUsesRoutineSound() {
        XCTAssertEqual(style(nil), NotificationStyle(interruptionLevel: .active, sound: .setting(.glass)))
        XCTAssertEqual(style(3, routine: .hero, high: .sosumi), NotificationStyle(interruptionLevel: .active, sound: .setting(.hero)))
    }

    func testHighPrioritiesUseHighSound() {
        XCTAssertEqual(style(4), NotificationStyle(interruptionLevel: .timeSensitive, sound: .setting(.critical)))
        XCTAssertEqual(style(5), NotificationStyle(interruptionLevel: .critical, sound: .setting(.critical)))
        XCTAssertEqual(style(4, routine: .none, high: .sosumi).sound, .setting(.sosumi))
        XCTAssertEqual(style(5, high: .sosumi).sound, .setting(.sosumi))
    }

    func testPassiveNotificationsSkipBannerAndSoundWhenFrontmost() {
        XCTAssertEqual(NotificationStyle.presentationOptions(for: .passive), [.list])
        XCTAssertEqual(NotificationStyle.presentationOptions(for: .active), [.banner, .sound, .badge])
    }
}
