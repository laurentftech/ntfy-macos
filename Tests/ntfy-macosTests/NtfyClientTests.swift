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

// MARK: - Mock URLProtocol for reconnect tests

/// Serves each request from a scripted response: a status code plus NDJSON lines.
/// The connection is then held open. Tracks how many requests are still loading,
/// so tests can detect subscriptions that were never cancelled.
final class ScriptedURLProtocol: URLProtocol {
    struct Response {
        var status = 200
        var lines: [String] = []
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _requests: [URL] = []
    nonisolated(unsafe) private static var _activeCount = 0
    nonisolated(unsafe) private static var generation = 0
    nonisolated(unsafe) static var respond: ((Int) -> Response) = { _ in Response() }

    static var requests: [URL] { lock.lock(); defer { lock.unlock() }; return _requests }
    static var activeCount: Int { lock.lock(); defer { lock.unlock() }; return _activeCount }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _requests = []
        _activeCount = 0
        generation += 1  // Loads left over from earlier tests no longer count
        respond = { _ in Response() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private var generation = -1

    override func startLoading() {
        ScriptedURLProtocol.lock.lock()
        generation = ScriptedURLProtocol.generation
        ScriptedURLProtocol._requests.append(request.url!)
        ScriptedURLProtocol._activeCount += 1
        let index = ScriptedURLProtocol._requests.count
        ScriptedURLProtocol.lock.unlock()

        let scripted = ScriptedURLProtocol.respond(index)
        // Like ntfy: an explicit Content-Type (URLSession otherwise buffers to sniff it),
        // and error responses carry a JSON body and then close.
        let response = HTTPURLResponse(
            url: request.url!, statusCode: scripted.status, httpVersion: nil,
            headerFields: ["Content-Type": "application/x-ndjson"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        guard scripted.status == 200 else {
            client?.urlProtocol(self, didLoad: Data(#"{"code":\#(scripted.status)}"#.utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        for line in [#"{"id":"open","time":0,"event":"open","topic":"test"}"#] + scripted.lines {
            client?.urlProtocol(self, didLoad: Data((line + "\n").utf8))
        }
    }

    override func stopLoading() {
        ScriptedURLProtocol.lock.lock()
        if generation == ScriptedURLProtocol.generation {
            ScriptedURLProtocol._activeCount -= 1
        }
        ScriptedURLProtocol.lock.unlock()
    }
}

private func messageLine(id: String, time: Int = 1_700_000_000) -> String {
    #"{"id":"\#(id)","time":\#(time),"event":"message","topic":"test","message":"hi"}"#
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

private func makeScriptedSessionConfig() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ScriptedURLProtocol.self]
    return config
}

/// Spins the main run loop until `condition` holds or `timeout` elapses.
@MainActor private func waitUntil(timeout: TimeInterval = 2.0, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return condition()
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

    func testConnectURLUsesJsonStreamPath() {
        let client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["a", "b"])
        XCTAssertEqual(client.buildConnectURL()?.absoluteString, "https://ntfy.sh/a,b/json")
    }

    func testConnectURLWithFetchMissedRequestsAllOnFirstConnect() {
        // A fresh server URL, so no cursor persisted by another test applies
        let serverURL = "https://first-connect-\(UUID().uuidString).example.com"
        let client = NtfyClient(serverURL: serverURL, topics: ["test"], fetchMissed: true)
        XCTAssertEqual(client.buildConnectURL()?.query, "since=all")
    }

    /// A server behind a reverse proxy keeps its path prefix
    func testConnectURLPreservesServerPathPrefix() {
        let client = NtfyClient(serverURL: "https://example.com/ntfy", topics: ["test"])
        XCTAssertEqual(client.buildConnectURL()?.path, "/ntfy/test/json")
    }

    func testConnectURLIgnoresTrailingSlash() {
        let client = NtfyClient(serverURL: "https://example.com/ntfy/", topics: ["test"])
        XCTAssertEqual(client.buildConnectURL()?.path, "/ntfy/test/json")
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

    // MARK: - Reconnect (issue #1: duplicate notifications)

    /// Overlapping reconnect triggers (watchdog, network monitor, errors) must leave
    /// exactly one subscription open, not one per trigger.
    @MainActor func testOverlappingReconnectsLeaveSingleSubscription() {
        ScriptedURLProtocol.reset()
        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 60.0, baseReconnectDelay: 0.05,
            urlSessionConfiguration: makeScriptedSessionConfig()
        )
        client.connect()
        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 1 })

        client.triggerReconnect()
        client.triggerReconnect()
        client.triggerReconnect()
        client.connect()  // Ignored only while a subscription is open; must not stack up either

        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count >= 2 })
        _ = waitUntil(timeout: 0.5) { false }  // Let any stray timers fire

        XCTAssertEqual(ScriptedURLProtocol.activeCount, 1)
        XCTAssertLessThanOrEqual(ScriptedURLProtocol.requests.count, 3)
        client.disconnect()
    }

    /// A message replayed on a new subscription must be delivered only once.
    @MainActor func testReplayedMessageIsDeliveredOnce() {
        ScriptedURLProtocol.reset()
        ScriptedURLProtocol.respond = { _ in .init(lines: [messageLine(id: "dup1")]) }

        var received: [String] = []
        let delegate = MockNtfyDelegate()
        delegate.onMessage = { received.append($0.id) }

        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 60.0, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeScriptedSessionConfig()
        )
        client.delegate = delegate
        client.connect()
        XCTAssertTrue(waitUntil { received.count == 1 })

        client.triggerReconnect()
        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 2 })
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertEqual(received, ["dup1"])
        client.disconnect()
    }

    /// A non-200 response must schedule a retry instead of leaving the client dead.
    @MainActor func testNon200ResponseTriggersReconnect() {
        ScriptedURLProtocol.reset()
        ScriptedURLProtocol.respond = { index in .init(status: index == 1 ? 503 : 200) }

        let connected = expectation(description: "Connected after retry")
        let delegate = MockNtfyDelegate()
        delegate.onConnect = { connected.fulfill() }

        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 60.0, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeScriptedSessionConfig()
        )
        client.delegate = delegate
        client.connect()

        wait(for: [connected], timeout: 2.0)
        XCTAssertEqual(ScriptedURLProtocol.requests.count, 2)
        client.disconnect()
    }

    /// With fetch_missed, reconnects resume after the last message ID (exclusive)
    /// rather than its timestamp (inclusive, which replays that message).
    @MainActor func testFetchMissedReconnectUsesLastMessageId() {
        ScriptedURLProtocol.reset()
        ScriptedURLProtocol.respond = { index in .init(lines: index == 1 ? [messageLine(id: "last1")] : []) }

        let serverURL = "https://fetch-missed-\(UUID().uuidString).example.com"
        defer {
            UserDefaults.standard.removeObject(forKey: "lastMessageTime-\(serverURL)-test")
            UserDefaults.standard.removeObject(forKey: "lastMessageId-\(serverURL)-test")
        }

        var received = 0
        let delegate = MockNtfyDelegate()
        delegate.onMessage = { _ in received += 1 }

        let client = NtfyClient(
            serverURL: serverURL, topics: ["test"], fetchMissed: true,
            watchdogInterval: 60.0, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeScriptedSessionConfig()
        )
        client.delegate = delegate
        client.connect()
        XCTAssertTrue(waitUntil { received == 1 })

        client.triggerReconnect()
        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 2 })

        let query = URLComponents(url: ScriptedURLProtocol.requests[1], resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first { $0.name == "since" }?.value, "last1")
        client.disconnect()
    }

    /// The URLSession retains its delegate; disconnect() must release it so a
    /// client dropped by a config reload is deallocated.
    @MainActor func testClientIsReleasedAfterDisconnect() {
        ScriptedURLProtocol.reset()
        weak var weakClient: NtfyClient?
        do {
            let client = NtfyClient(
                serverURL: "https://ntfy.sh", topics: ["test"],
                watchdogInterval: 60.0, baseReconnectDelay: 0.0,
                urlSessionConfiguration: makeScriptedSessionConfig()
            )
            weakClient = client
            client.connect()
            XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 1 })
            client.disconnect()
        }
        XCTAssertTrue(waitUntil { weakClient == nil })
    }

    /// A client must be able to connect again after disconnect().
    @MainActor func testConnectAfterDisconnect() {
        ScriptedURLProtocol.reset()
        let client = NtfyClient(
            serverURL: "https://ntfy.sh", topics: ["test"],
            watchdogInterval: 60.0, baseReconnectDelay: 0.0,
            urlSessionConfiguration: makeScriptedSessionConfig()
        )
        client.connect()
        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 1 })
        client.disconnect()
        client.connect()
        XCTAssertTrue(waitUntil { ScriptedURLProtocol.requests.count == 2 && ScriptedURLProtocol.activeCount == 1 })
        client.disconnect()
    }
}
