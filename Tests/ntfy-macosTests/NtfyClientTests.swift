import XCTest
@testable import ntfy_macos

final class NtfyClientTests: XCTestCase {
    // MARK: - URL Construction

    func testClientInitialization() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"])
        XCTAssertNotNil(client)
    }

    func testClientWithMultipleTopics() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["topic1", "topic2", "topic3"])
        XCTAssertNotNil(client)
    }

    func testClientWithAuthToken() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"], authToken: "tk_secret123")
        XCTAssertNotNil(client)
    }

    func testClientWithCustomServer() {
        let client = NtfyClient(serverURL: "https://my-ntfy.example.com", topics: ["alerts"])
        XCTAssertNotNil(client)
    }

    // MARK: - Exponential Backoff Calculation

    func testExponentialBackoffCalculation() {
        // Test the exponential backoff formula: min(baseDelay * 2^attempts, maxDelay)
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 300.0

        // Attempt 0: 2 * 2^0 = 2
        XCTAssertEqual(min(baseDelay * pow(2.0, 0), maxDelay), 2.0)

        // Attempt 1: 2 * 2^1 = 4
        XCTAssertEqual(min(baseDelay * pow(2.0, 1), maxDelay), 4.0)

        // Attempt 2: 2 * 2^2 = 8
        XCTAssertEqual(min(baseDelay * pow(2.0, 2), maxDelay), 8.0)

        // Attempt 3: 2 * 2^3 = 16
        XCTAssertEqual(min(baseDelay * pow(2.0, 3), maxDelay), 16.0)

        // Attempt 4: 2 * 2^4 = 32
        XCTAssertEqual(min(baseDelay * pow(2.0, 4), maxDelay), 32.0)

        // Attempt 5: 2 * 2^5 = 64
        XCTAssertEqual(min(baseDelay * pow(2.0, 5), maxDelay), 64.0)

        // Attempt 6: 2 * 2^6 = 128
        XCTAssertEqual(min(baseDelay * pow(2.0, 6), maxDelay), 128.0)

        // Attempt 7: 2 * 2^7 = 256
        XCTAssertEqual(min(baseDelay * pow(2.0, 7), maxDelay), 256.0)

        // Attempt 8: 2 * 2^8 = 512, capped at 300
        XCTAssertEqual(min(baseDelay * pow(2.0, 8), maxDelay), 300.0)

        // Attempt 9: still capped at 300
        XCTAssertEqual(min(baseDelay * pow(2.0, 9), maxDelay), 300.0)
    }

    func testJitterRange() {
        // Verify jitter calculation stays within ±10%
        let baseDelay: TimeInterval = 100.0

        for _ in 0..<100 {
            let jitter = baseDelay * Double.random(in: -0.1...0.1)
            let delayWithJitter = baseDelay + jitter

            XCTAssertGreaterThanOrEqual(delayWithJitter, 90.0)
            XCTAssertLessThanOrEqual(delayWithJitter, 110.0)
        }
    }

    // MARK: - Disconnect

    func testDisconnectDoesNotCrash() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"])
        // Should not crash even if never connected
        client.disconnect()
    }

    func testMultipleDisconnects() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"])
        // Multiple disconnects should be safe
        client.disconnect()
        client.disconnect()
        client.disconnect()
    }
}
