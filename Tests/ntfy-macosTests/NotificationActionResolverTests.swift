import XCTest
@testable import ntfy_macos

class NotificationActionResolverTests: XCTestCase {
    func testScriptActionIsChosenOverURL() {
        let message = NtfyMessage(
            id: "msg1",
            time: 1,
            event: "message",
            topic: "test",
            message: "Hello",
            title: "Test",
            priority: nil,
            tags: nil,
            click: nil,
            actions: [
                NtfyMessage.NtfyAction(
                    action: "view",
                    label: "Open",
                    url: "https://example.com",
                    method: nil,
                    headers: nil,
                    body: nil,
                    clear: nil
                ),
                NtfyMessage.NtfyAction(
                    action: "script",
                    label: "Run",
                    url: "file:///tmp/test.sh",
                    method: nil,
                    headers: nil,
                    body: nil,
                    clear: nil
                )
            ],
            attachment: nil,
            contentType: nil
        )

        let resolver = NotificationActionResolver()
        let action = resolver.resolve(from: message)

        XCTAssertEqual(action, .script(path: "/tmp/test.sh"))
    }

    func testViewActionIsChosenWhenNoScriptAction() {
        let message = NtfyMessage(
            id: "msg1",
            time: 1,
            event: "message",
            topic: "test",
            message: "Hello",
            title: "Test",
            priority: nil,
            tags: nil,
            click: nil,
            actions: [
                NtfyMessage.NtfyAction(
                    action: "view",
                    label: "Open",
                    url: "https://example.com",
                    method: nil,
                    headers: nil,
                    body: nil,
                    clear: nil
                )
            ],
            attachment: nil,
            contentType: nil
        )

        let resolver = NotificationActionResolver()
        let action = resolver.resolve(from: message)

        XCTAssertEqual(action, .view(url: URL(string: "https://example.com")!))
    }

    func testClickURLIsUsedAsFallback() {
        let message = NtfyMessage(
            id: "msg1",
            time: 1,
            event: "message",
            topic: "test",
            message: "Hello",
            title: "Test",
            priority: nil,
            tags: nil,
            click: "https://example.com/click",
            actions: [],
            attachment: nil,
            contentType: nil
        )

        let resolver = NotificationActionResolver()
        let action = resolver.resolve(from: message)

        XCTAssertEqual(action, .view(url: URL(string: "https://example.com/click")!))
    }

    func testNoActionIsReturnedWhenNoActionsOrClickURL() {
        let message = NtfyMessage(
            id: "msg1",
            time: 1,
            event: "message",
            topic: "test",
            message: "Hello",
            title: "Test",
            priority: nil,
            tags: nil,
            click: nil,
            actions: [],
            attachment: nil,
            contentType: nil
        )

        let resolver = NotificationActionResolver()
        let action = resolver.resolve(from: message)

        XCTAssertEqual(action, .none)
    }

    func testMalformedURLinActionIsIgnored() {
        let message = NtfyMessage(
            id: "msg1",
            time: 1,
            event: "message",
            topic: "test",
            message: "Hello",
            title: "Test",
            priority: nil,
            tags: nil,
            click: nil,
            actions: [
                NtfyMessage.NtfyAction(
                    action: "view",
                    label: "View",
                    url: "a malformed url",
                    method: nil,
                    headers: nil,
                    body: nil,
                    clear: nil
                )
            ],
            attachment: nil,
            contentType: nil
        )

        let resolver = NotificationActionResolver()
        let action = resolver.resolve(from: message)

        XCTAssertEqual(action, .none)
    }
}
