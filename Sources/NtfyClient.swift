import Foundation
import Network

@preconcurrency protocol NtfyClientDelegate: AnyObject {
    func ntfyClient(_ client: NtfyClient, didReceiveMessage message: NtfyMessage)
    func ntfyClient(_ client: NtfyClient, didEncounterError error: Error)
    func ntfyClientDidConnect(_ client: NtfyClient)
    func ntfyClientDidDisconnect(_ client: NtfyClient)
}

struct NtfyMessage: Codable {
    let id: String
    let time: Int
    let event: String
    let topic: String
    let message: String?
    let title: String?
    let priority: Int?
    let tags: [String]?
    let click: String?
    let actions: [NtfyAction]?
    let attachment: NtfyAttachment?
    let contentType: String?  // "text/markdown" when markdown is enabled

    enum CodingKeys: String, CodingKey {
        case id, time, event, topic, message, title, priority, tags, click, actions, attachment
        case contentType = "content_type"
    }

    /// Returns true if this message contains markdown content
    var isMarkdown: Bool {
        contentType?.lowercased() == "text/markdown"
    }

    /// Returns the message with markdown syntax stripped for plain text display
    var plainTextMessage: String? {
        guard let message = message else { return nil }
        guard isMarkdown else { return message }
        return MarkdownStripper.strip(message)
    }

    /// Returns the title with markdown syntax stripped for plain text display
    var plainTextTitle: String? {
        guard let title = title else { return nil }
        guard isMarkdown else { return title }
        return MarkdownStripper.strip(title)
    }

    struct NtfyAction: Codable {
        let action: String
        let label: String
        let url: String?
        let method: String?
        let headers: [String: String]?
        let body: String?
        let clear: Bool?
    }

    struct NtfyAttachment: Codable {
        let name: String
        let url: String
        let type: String?
        let size: Int?
        let expires: Int?
    }
}

/// Streams messages from an ntfy server and reconnects on failure.
///
/// All mutable state is confined to `queue`: URLSession callbacks, timers and the
/// network path monitor all run there, and the public entry points hop onto it.
/// Callbacks from a task that is no longer the current `dataTask` are ignored, so a
/// cancelled or replaced subscription can never reset state or deliver messages.
final class NtfyClient: NSObject, @unchecked Sendable {
    private let serverURL: String
    private let topics: [String]
    private let fetchMissed: Bool
    private var authToken: String?

    weak var delegate: NtfyClientDelegate?

    private let queue = DispatchQueue(label: "com.ntfy-macos.client")
    // URLSession retains its delegate, so the session is invalidated on disconnect
    // (letting the client deallocate) and recreated on the next connect.
    private let sessionConfiguration: URLSessionConfiguration
    private var session: URLSession?
    private let delegateQueue: OperationQueue
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval
    private let maxReconnectDelay: TimeInterval = 300.0  // 5 minutes max
    private var reconnectTimer: DispatchSourceTimer?
    private var shouldReconnect = true
    private var retryAfterDelay: TimeInterval?  // From Retry-After header

    // fetch_missed state: the last message seen, persisted so reconnects resume after it
    private var lastMessageTime: Int
    private var lastMessageId: String?
    private let lastMessageTimeKey: String
    private let lastMessageIdKey: String

    // Recently delivered message IDs, so a message replayed by the server is shown once
    private var recentMessageIds: [String] = []
    private var recentMessageIdSet: Set<String> = []
    private let maxRecentMessageIds = 500

    // Watchdog: reconnect if no data received for this long (ntfy sends keepalives every ~55s)
    private let watchdogInterval: TimeInterval
    private var watchdogTimer: DispatchSourceTimer?
    private var lastDataReceived: Date = .distantPast

    // Network path monitor: reconnect immediately when network becomes available
    private var pathMonitor: NWPathMonitor?
    private var isPathSatisfied = true  // Assume connected initially

    init(serverURL: String, topics: [String], authToken: String? = nil, fetchMissed: Bool = false, watchdogInterval: TimeInterval = 120.0, baseReconnectDelay: TimeInterval = 2.0, urlSessionConfiguration: URLSessionConfiguration? = nil) {
        self.serverURL = serverURL
        self.topics = topics
        self.authToken = authToken
        self.fetchMissed = fetchMissed
        self.watchdogInterval = watchdogInterval
        self.baseReconnectDelay = baseReconnectDelay

        // Restore the last message seen from UserDefaults for fetch_missed
        let topicsKey = topics.sorted().joined(separator: ",")
        self.lastMessageTimeKey = "lastMessageTime-\(serverURL)-\(topicsKey)"
        self.lastMessageIdKey = "lastMessageId-\(serverURL)-\(topicsKey)"
        self.lastMessageTime = UserDefaults.standard.integer(forKey: lastMessageTimeKey)
        self.lastMessageId = UserDefaults.standard.string(forKey: lastMessageIdKey)

        // URLSession callbacks run on the same serial queue as everything else
        self.delegateQueue = OperationQueue()
        self.delegateQueue.maxConcurrentOperationCount = 1
        self.delegateQueue.name = "com.ntfy-macos.urlsession"
        self.delegateQueue.underlyingQueue = queue

        let config = urlSessionConfiguration ?? URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        config.httpMaximumConnectionsPerHost = 1
        self.sessionConfiguration = config

        super.init()
    }

    deinit {
        // Can't hop onto the queue from deinit; these cancels are thread-safe.
        reconnectTimer?.cancel()
        watchdogTimer?.cancel()
        pathMonitor?.cancel()
        dataTask?.cancel()
    }

    // Thread-safe delegate call helper
    private func callDelegate(_ block: @escaping @Sendable (NtfyClientDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let delegate = self.delegate else { return }
            block(delegate)
        }
    }

    func connect() {
        queue.async { [weak self] in
            guard let self, self.dataTask == nil else { return }
            self.shouldReconnect = true
            self.startConnection()
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.shouldReconnect = false
            self.cancelReconnectTimer()
            self.stopWatchdog()
            self.stopPathMonitor()
            self.dataTask?.cancel()
            self.dataTask = nil
            self.buffer.removeAll()
            self.session?.invalidateAndCancel()
            self.session = nil
        }
    }

    func updateAuthToken(_ token: String?) {
        queue.async { [weak self] in
            guard let self else { return }
            self.authToken = token
            if self.dataTask != nil {
                self.reconnect()
            }
        }
    }

    /// Forces a reconnect as if the watchdog fired. Internal for testing.
    func triggerReconnect() {
        queue.async { [weak self] in
            self?.reconnect()
        }
    }

    /// Starts a new subscription, replacing any existing one. Must run on `queue`.
    private func startConnection() {
        guard shouldReconnect else { return }

        let topicsString = topics.joined(separator: ",")
        guard var components = URLComponents(string: serverURL) else { return }

        components.path = "/\(topicsString)/json"

        // Add since parameter to fetch missed messages when enabled
        if fetchMissed {
            if let lastMessageId {
                // Reconnect: `since=<id>` is exclusive, so the last message isn't replayed
                components.queryItems = [URLQueryItem(name: "since", value: lastMessageId)]
            } else if lastMessageTime > 0 {
                // Only a timestamp persisted by an older version is available
                components.queryItems = [URLQueryItem(name: "since", value: String(lastMessageTime))]
            } else {
                // First connect: fetch all cached messages
                components.queryItems = [URLQueryItem(name: "since", value: "all")]
            }
        }

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        startPathMonitor()

        // Never leave a previous subscription streaming alongside the new one
        cancelReconnectTimer()
        stopWatchdog()
        dataTask?.cancel()
        buffer.removeAll()
        let session = self.session ?? URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: delegateQueue)
        self.session = session
        dataTask = session.dataTask(with: request)
        dataTask?.resume()

        Log.info("Connecting to ntfy: \(url.absoluteString)")
    }

    private func startWatchdog() {
        stopWatchdog()
        lastDataReceived = Date()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + watchdogInterval, repeating: watchdogInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.lastDataReceived)
            if elapsed >= self.watchdogInterval {
                Log.info("Watchdog: no data received for \(Int(elapsed))s, reconnecting...")
                self.reconnect()
            }
        }
        watchdogTimer = timer
        timer.resume()
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
    }

    private func startPathMonitor() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            guard let self, let monitor, self.pathMonitor === monitor else { return }
            let satisfied = path.status == .satisfied
            if satisfied && !self.isPathSatisfied {
                Log.info("Network became available, reconnecting...")
                self.reconnect()
            }
            self.isPathSatisfied = satisfied
        }
        monitor.start(queue: queue)
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        isPathSatisfied = true
    }

    private func cancelReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    /// Tears down the current subscription and schedules a new one. Must run on `queue`.
    private func reconnect() {
        guard shouldReconnect else { return }

        dataTask?.cancel()
        dataTask = nil
        stopWatchdog()
        buffer.removeAll()

        // Calculate delay with exponential backoff
        var delay: TimeInterval

        if let retryAfter = retryAfterDelay {
            // Server told us exactly when to retry (Retry-After header)
            delay = retryAfter
            retryAfterDelay = nil  // Clear for next time
            Log.info("Server requested retry after \(Int(delay)) seconds")
        } else {
            // Exponential backoff: 2s, 4s, 8s, 16s, 32s, 64s, 128s, 256s, 300s (capped)
            delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)
        }

        // Add jitter (±10%) to prevent thundering herd
        let jitter = delay * Double.random(in: -0.1...0.1)
        delay += jitter

        reconnectAttempts += 1

        if reconnectAttempts <= maxReconnectAttempts {
            Log.info("Reconnecting in \(String(format: "%.1f", delay)) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))...")
        } else {
            // Max attempts reached — schedule a last-resort retry every 5 minutes indefinitely
            Log.error("Max reconnection attempts reached. Retrying every 5 minutes...")
            reconnectAttempts = 0  // Reset so next success resets state correctly
            delay = 300.0
        }

        // Replace any pending reconnect so only one is ever outstanding
        cancelReconnectTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + max(delay, 0))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.reconnectTimer = nil
            self.startConnection()
        }
        reconnectTimer = timer
        timer.resume()
    }

    /// Parse Retry-After header value (can be seconds or HTTP date)
    /// Internal for testing
    func parseRetryAfter(_ value: String) -> TimeInterval {
        // Try parsing as seconds first
        if let seconds = TimeInterval(value) {
            return max(seconds, 1.0)  // At least 1 second
        }

        // Try parsing as HTTP date (e.g., "Sun, 18 Jan 2026 23:59:59 GMT")
        let httpDateFormatter = DateFormatter()
        httpDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        httpDateFormatter.timeZone = TimeZone(identifier: "GMT")

        // RFC 7231 formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // IMF-fixdate
            "EEEE, dd-MMM-yy HH:mm:ss zzz",   // RFC 850
            "EEE MMM d HH:mm:ss yyyy"          // ANSI C asctime()
        ]

        for format in formats {
            httpDateFormatter.dateFormat = format
            if let date = httpDateFormatter.date(from: value) {
                let delay = date.timeIntervalSinceNow
                return max(delay, 1.0)  // At least 1 second, even if date is in past
            }
        }

        // Fallback if parsing fails
        return 30.0
    }

    /// Records a message ID; returns false if it was already delivered recently.
    private func rememberMessageId(_ id: String) -> Bool {
        guard recentMessageIdSet.insert(id).inserted else { return false }
        recentMessageIds.append(id)
        if recentMessageIds.count > maxRecentMessageIds {
            recentMessageIdSet.remove(recentMessageIds.removeFirst())
        }
        return true
    }

    private func processLine(_ line: String) {
        guard !line.isEmpty else { return }

        do {
            let data = Data(line.utf8)
            let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

            guard message.event == "message" else { return }

            // A message ID unknown to the server makes `since=<id>` return the whole
            // cache, so drop anything older than what was already seen.
            if fetchMissed && message.time < lastMessageTime {
                return
            }
            guard rememberMessageId(message.id) else {
                return
            }

            // Track the latest message for fetch_missed reconnects
            if message.time >= lastMessageTime {
                lastMessageTime = message.time
                lastMessageId = message.id
                if fetchMissed {
                    UserDefaults.standard.set(lastMessageTime, forKey: lastMessageTimeKey)
                    UserDefaults.standard.set(message.id, forKey: lastMessageIdKey)
                }
            }

            callDelegate { delegate in
                delegate.ntfyClient(self, didReceiveMessage: message)
            }
        } catch {
            Log.error("Failed to decode message: \(error)")
        }
    }
}

extension NtfyClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask === self.dataTask else { return }

        lastDataReceived = Date()
        buffer.append(data)

        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0..<newlineRange.upperBound)

            if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                processLine(line)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // A cancelled or replaced task must not touch the current subscription's state
        guard task === self.dataTask else { return }

        dataTask = nil
        stopWatchdog()

        if let error = error {
            Log.error("Connection error: \(error.localizedDescription)")
            callDelegate { delegate in
                delegate.ntfyClient(self, didEncounterError: error)
                delegate.ntfyClientDidDisconnect(self)
            }
        } else {
            Log.info("Connection closed by server")
            callDelegate { delegate in
                delegate.ntfyClientDidDisconnect(self)
            }
        }
        reconnect()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard dataTask === self.dataTask, let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        if httpResponse.statusCode == 200 {
            reconnectAttempts = 0
            startWatchdog()
            callDelegate { delegate in
                delegate.ntfyClientDidConnect(self)
            }
            completionHandler(.allow)
        } else {
            Log.error("Server returned status code: \(httpResponse.statusCode)")

            // Handle rate limiting (429) - extract Retry-After header
            if httpResponse.statusCode == 429 {
                if let retryAfterString = httpResponse.value(forHTTPHeaderField: "Retry-After") {
                    retryAfterDelay = parseRetryAfter(retryAfterString)
                } else {
                    // No Retry-After header, use a conservative default for 429
                    retryAfterDelay = 30.0
                }
            }

            completionHandler(.cancel)
            // The cancelled task's completion is ignored, so schedule the retry here
            callDelegate { delegate in
                delegate.ntfyClientDidDisconnect(self)
            }
            reconnect()
        }
    }
}
