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
}
