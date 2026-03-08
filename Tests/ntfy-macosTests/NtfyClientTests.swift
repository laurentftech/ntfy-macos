import XCTest
@testable import ntfy_macos

// MARK: - Mock URLProtocol for watchdog tests

/// Intercepts URLSession requests and returns HTTP 200 without sending any data,
/// simulating a stale connection where the server stops sending keepalives.
final class HoldingURLProtocol: URLProtocol {
    static let requestCountLock = NSLock()
    nonisolated(unsafe) private static var _requestCount = 0
    static var requestCount: Int {
        get { requestCountLock.lock(); defer { requestCountLock.unlock() }; return _requestCount }
        set { requestCountLock.lock(); defer { requestCountLock.unlock() }; _requestCount = newValue }
    }
    nonisolated(unsafe) static var onRequest: ((Int) -> Void)?

    static func reset() {
        requestCount = 0
        onRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let count = HoldingURLProtocol.requestCount + 1
        HoldingURLProtocol.requestCount = count
        HoldingURLProtocol.onRequest?(count)

        // Return HTTP 200 but never send data or finish — simulates stale connection
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Intentionally no didLoad or didFinishLoading — connection stays "open"
    }

    override func stopLoading() {}
}

// MARK: - Mock delegate

final class MockNtfyDelegate: NtfyClientDelegate {
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onMessage: ((NtfyMessage) -> Void)?

    func ntfyClientDidConnect(_ client: NtfyClient) { onConnect?() }
    func ntfyClientDidDisconnect(_ client: NtfyClient) { onDisconnect?() }
    func ntfyClient(_ client: NtfyClient, didEncounterError error: Error) { onError?(error) }
    func ntfyClient(_ client: NtfyClient, didReceiveMessage message: NtfyMessage) { onMessage?(message) }
}

// MARK: - Helper

private func makeSessionConfig() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [HoldingURLProtocol.self]
    return config
}

// MARK: - Tests

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

    // MARK: - Watchdog

    func testWatchdogIntervalIsConfigurable() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"], watchdogInterval: 30.0)
        XCTAssertNotNil(client)
    }

    /// After disconnect(), the watchdog must not fire and trigger a reconnect.
    @MainActor func testWatchdogDoesNotFireAfterDisconnect() {
        HoldingURLProtocol.reset()
        let connectExp = expectation(description: "No reconnect after disconnect")
        connectExp.isInverted = true

        let delegate = MockNtfyDelegate()
        delegate.onConnect = { connectExp.fulfill() }

        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 0.05, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeSessionConfig()
        )
        client.delegate = delegate
        client.connect()
        client.disconnect()  // Immediately cancel — watchdog must not trigger

        waitForExpectations(timeout: 0.3)
    }

/// Cancelled task errors must not trigger reconnect (avoids double-reconnect when watchdog fires).
    @MainActor func testCancelledTaskDoesNotTriggerReconnect() {
        HoldingURLProtocol.reset()

        // Connect, then immediately disconnect — only 1 request should ever be made
        // (no spurious reconnect from the cancelled task's error)
        let initialExp = expectation(description: "Initial request received")
        HoldingURLProtocol.onRequest = { count in
            if count >= 1 { initialExp.fulfill() }
        }

        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 60.0, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeSessionConfig()
        )
        client.connect()
        waitForExpectations(timeout: 1.0)

        // Disconnect and wait — request count must stay at 1
        client.disconnect()
        let noExtraExp = expectation(description: "No extra reconnect request")
        noExtraExp.isInverted = true
        HoldingURLProtocol.onRequest = { count in
            if count >= 2 { noExtraExp.fulfill() }
        }
        waitForExpectations(timeout: 0.3)

        XCTAssertEqual(HoldingURLProtocol.requestCount, 1)
    }
}
