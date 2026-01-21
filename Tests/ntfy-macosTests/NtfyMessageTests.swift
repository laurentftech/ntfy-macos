import XCTest
@testable import ntfy_macos

final class NtfyMessageTests: XCTestCase {
    func testBasicMessageDecoding() throws {
        let json = """
        {
            "id": "abc123",
            "time": 1234567890,
            "event": "message",
            "topic": "test",
            "message": "Hello World"
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertEqual(message.id, "abc123")
        XCTAssertEqual(message.time, 1234567890)
        XCTAssertEqual(message.event, "message")
        XCTAssertEqual(message.topic, "test")
        XCTAssertEqual(message.message, "Hello World")
        XCTAssertNil(message.title)
        XCTAssertNil(message.priority)
        XCTAssertNil(message.tags)
    }

    func testFullMessageDecoding() throws {
        let json = """
        {
            "id": "xyz789",
            "time": 1234567890,
            "event": "message",
            "topic": "alerts",
            "message": "Server is down!",
            "title": "Alert",
            "priority": 5,
            "tags": ["warning", "fire"],
            "click": "https://example.com"
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertEqual(message.id, "xyz789")
        XCTAssertEqual(message.title, "Alert")
        XCTAssertEqual(message.priority, 5)
        XCTAssertEqual(message.tags, ["warning", "fire"])
        XCTAssertEqual(message.click, "https://example.com")
    }

    func testMessageWithActions() throws {
        let json = """
        {
            "id": "act123",
            "time": 1234567890,
            "event": "message",
            "topic": "test",
            "message": "Test with actions",
            "actions": [
                {
                    "action": "view",
                    "label": "Open",
                    "url": "https://example.com"
                },
                {
                    "action": "http",
                    "label": "Acknowledge",
                    "url": "https://api.example.com/ack",
                    "method": "POST",
                    "body": "{}",
                    "clear": true
                }
            ]
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertEqual(message.actions?.count, 2)
        XCTAssertEqual(message.actions?[0].action, "view")
        XCTAssertEqual(message.actions?[0].label, "Open")
        XCTAssertEqual(message.actions?[1].method, "POST")
        XCTAssertEqual(message.actions?[1].clear, true)
    }

    func testMessageWithAttachment() throws {
        let json = """
        {
            "id": "att123",
            "time": 1234567890,
            "event": "message",
            "topic": "test",
            "message": "File attached",
            "attachment": {
                "name": "document.pdf",
                "url": "https://example.com/document.pdf",
                "type": "application/pdf",
                "size": 102400,
                "expires": 1234570000
            }
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertNotNil(message.attachment)
        XCTAssertEqual(message.attachment?.name, "document.pdf")
        XCTAssertEqual(message.attachment?.url, "https://example.com/document.pdf")
        XCTAssertEqual(message.attachment?.type, "application/pdf")
        XCTAssertEqual(message.attachment?.size, 102400)
    }

    func testOpenEvent() throws {
        let json = """
        {
            "id": "open123",
            "time": 1234567890,
            "event": "open",
            "topic": "test"
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertEqual(message.event, "open")
        XCTAssertNil(message.message)
    }

    func testKeepaliveEvent() throws {
        let json = """
        {
            "id": "ka123",
            "time": 1234567890,
            "event": "keepalive",
            "topic": "test"
        }
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

        XCTAssertEqual(message.event, "keepalive")
    }
}
