import Foundation
import Network

/// A minimal HTTP server bound to localhost that accepts POST requests
/// to trigger local macOS notifications. This allows scripts (e.g., auto_run_script)
/// to generate notifications without going through an external ntfy server.
///
/// Usage: POST http://127.0.0.1:<port>/notify
///   Body: {"title": "...", "message": "...", "priority": 3, "tags": ["warning"]}
final class LocalNotificationServer: @unchecked Sendable {
    private var listener: NWListener?
    private let port: UInt16
    private let maxBodySize = 4096
    private let queue = DispatchQueue(label: "com.ntfy-macos.local-server")
    /// Callback for handling notifications. Set to nil to disable notification display (useful for testing).
    var onNotification: (@Sendable (NtfyMessage) -> Void)?

    init(port: UInt16) {
        self.port = port
        self.onNotification = { message in
            DispatchQueue.main.async {
                NotificationManager.shared.showNotification(for: message, topicConfig: nil)
            }
        }
    }

    func start() throws {
        let params = NWParameters.tcp
        // Bind to localhost only
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)

        listener = try NWListener(using: params)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                Log.info("Local notification server listening on 127.0.0.1:\(self.port)")
            case .failed(let error):
                Log.error("Local notification server failed: \(error)")
            case .cancelled:
                Log.info("Local notification server stopped")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        readData(connection: connection, buffer: Data())
    }

    /// Accumulates data from the connection until the full HTTP request is received
    private func readData(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxBodySize + 2048) { [weak self] data, _, isComplete, error in
            guard let self = self else {
                connection.cancel()
                return
            }

            if let error = error {
                Log.error("Local server connection error: \(error)")
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data = data {
                accumulated.append(data)
            }

            // Check if we have the complete HTTP request
            if let raw = String(data: accumulated, encoding: .utf8),
               let headerEnd = raw.range(of: "\r\n\r\n") {
                // We have the headers, check if we need more body data
                let headers = String(raw[..<headerEnd.lowerBound])
                let bodyStart = raw[headerEnd.upperBound...]
                let contentLength = self.parseContentLength(from: headers)

                if bodyStart.utf8.count >= contentLength || isComplete {
                    // We have the full request
                    self.processRequest(data: accumulated, connection: connection)
                    return
                }
            }

            if isComplete {
                // Connection closed, process what we have
                if accumulated.isEmpty {
                    self.sendResponse(connection: connection, status: 400, body: "{\"error\":\"No data received\"}")
                } else {
                    self.processRequest(data: accumulated, connection: connection)
                }
                return
            }

            // Need more data, keep reading
            if accumulated.count > self.maxBodySize + 4096 {
                self.sendResponse(connection: connection, status: 413, body: "{\"error\":\"Request too large\"}")
                return
            }

            self.readData(connection: connection, buffer: accumulated)
        }
    }

    /// Parse Content-Length header value from raw headers string
    private func parseContentLength(from headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }

    private func processRequest(data: Data, connection: NWConnection) {
        guard let raw = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Invalid encoding\"}")
            return
        }

        // Parse HTTP request line
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Empty request\"}")
            return
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Malformed request\"}")
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        // Only accept POST /notify
        guard method == "POST" && path == "/notify" else {
            if method == "GET" && path == "/health" {
                sendResponse(connection: connection, status: 200, body: "{\"status\":\"ok\"}")
                return
            }
            sendResponse(connection: connection, status: 404, body: "{\"error\":\"Not found. Use POST /notify or GET /health\"}")
            return
        }

        // Extract body (after empty line)
        guard let bodyRange = raw.range(of: "\r\n\r\n") else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"No body\"}")
            return
        }

        let bodyString = String(raw[bodyRange.upperBound...])
        guard bodyString.utf8.count <= maxBodySize else {
            sendResponse(connection: connection, status: 413, body: "{\"error\":\"Body too large (max \(maxBodySize) bytes)\"}")
            return
        }

        guard let bodyData = bodyString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Invalid JSON\"}")
            return
        }

        // Parse notification fields
        guard let title = json["title"] as? String, !title.isEmpty else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Missing required field: title\"}")
            return
        }
        guard let message = json["message"] as? String, !message.isEmpty else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Missing required field: message\"}")
            return
        }

        let priority = json["priority"] as? Int
        let tags = json["tags"] as? [String]

        Log.info("Local notification: \(title) - \(message)")

        // Build an NtfyMessage-like structure and show notification
        let localMessage = NtfyMessage(
            id: UUID().uuidString,
            time: Int(Date().timeIntervalSince1970),
            event: "message",
            topic: "local",
            message: message,
            title: title,
            priority: priority,
            tags: tags,
            click: nil,
            actions: nil,
            attachment: nil,
            contentType: nil
        )

        onNotification?(localMessage)

        sendResponse(connection: connection, status: 200, body: "{\"success\":true}")
    }

    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 413: statusText = "Payload Too Large"
        default: statusText = "Error"
        }

        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"

        connection.send(content: response.data(using: .utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
