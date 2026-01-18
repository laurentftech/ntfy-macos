import Foundation

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

final class NtfyClient: NSObject, @unchecked Sendable {
    private let serverURL: String
    private let topics: [String]
    private let lock = NSLock()
    private var _authToken: String?

    private var authToken: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _authToken
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _authToken = newValue
        }
    }

    weak var delegate: NtfyClientDelegate?

    private var session: URLSession!
    private let delegateQueue: OperationQueue
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 2.0
    private var reconnectTimer: Timer?
    private var isConnecting = false
    private var shouldReconnect = true

    init(serverURL: String, topics: [String], authToken: String? = nil) {
        self.serverURL = serverURL
        self.topics = topics
        self._authToken = authToken

        // Create a dedicated serial queue for URLSession callbacks
        self.delegateQueue = OperationQueue()
        self.delegateQueue.maxConcurrentOperationCount = 1
        self.delegateQueue.name = "com.ntfy-macos.urlsession"

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        config.httpMaximumConnectionsPerHost = 1
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    }

    deinit {
        disconnect()
    }

    // Thread-safe delegate call helper
    private func callDelegate(_ block: @escaping @Sendable (NtfyClientDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let delegate = self.delegate else { return }
            block(delegate)
        }
    }

    func connect() {
        guard !isConnecting else { return }
        isConnecting = true

        let topicsString = topics.joined(separator: ",")
        guard var components = URLComponents(string: serverURL) else {
            isConnecting = false
            return
        }

        components.path = "/\(topicsString)/json"

        guard let url = components.url else {
            isConnecting = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        buffer.removeAll()
        dataTask = session.dataTask(with: request)
        dataTask?.resume()

        Log.info("Connecting to ntfy: \(url.absoluteString)")
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        dataTask?.cancel()
        dataTask = nil
        isConnecting = false
        buffer.removeAll()
    }

    func updateAuthToken(_ token: String?) {
        self.authToken = token
        if dataTask != nil {
            reconnect()
        }
    }

    private func reconnect() {
        guard shouldReconnect else { return }

        dataTask?.cancel()
        dataTask = nil
        isConnecting = false

        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts)), 60.0)
        reconnectAttempts += 1

        if reconnectAttempts <= maxReconnectAttempts {
            Log.info("Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))...")

            // Schedule timer on main thread to ensure RunLoop is active
            DispatchQueue.main.async { [weak self] in
                self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.connect()
                }
            }
        } else {
            Log.error("Max reconnection attempts reached. Please restart the service.")
            let error = NSError(
                domain: "NtfyClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Max reconnection attempts reached"]
            )
            callDelegate { delegate in
                delegate.ntfyClient(self, didEncounterError: error)
            }
        }
    }

    private func processLine(_ line: String) {
        guard !line.isEmpty else { return }

        do {
            let data = Data(line.utf8)
            let message = try JSONDecoder().decode(NtfyMessage.self, from: data)

            if message.event == "message" {
                callDelegate { delegate in
                    delegate.ntfyClient(self, didReceiveMessage: message)
                }
            }
        } catch {
            Log.error("Failed to decode message: \(error)")
        }
    }
}

extension NtfyClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
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
        isConnecting = false

        if let error = error {
            // Don't log cancelled errors (normal during reconnect)
            let nsError = error as NSError
            if nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled {
                Log.error("Connection error: \(error.localizedDescription)")
            }
            callDelegate { delegate in
                delegate.ntfyClient(self, didEncounterError: error)
                delegate.ntfyClientDidDisconnect(self)
            }
            reconnect()
        } else {
            Log.info("Connection closed by server")
            callDelegate { delegate in
                delegate.ntfyClientDidDisconnect(self)
            }
            if shouldReconnect {
                reconnect()
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        if httpResponse.statusCode == 200 {
            isConnecting = false
            reconnectAttempts = 0
            callDelegate { delegate in
                delegate.ntfyClientDidConnect(self)
            }
            completionHandler(.allow)
        } else {
            Log.error("Server returned status code: \(httpResponse.statusCode)")
            completionHandler(.cancel)
        }
    }
}
