import XCTest
import Network
@testable import ntfy_macos

final class LocalNotificationServerTests: XCTestCase {
    var server: LocalNotificationServer!
    let testPort: UInt16 = 19292  // Use a non-standard port for tests

    override func setUp() {
        super.setUp()
        server = LocalNotificationServer(port: testPort)
        server.onNotification = nil  // Disable actual notifications in tests
        try? server.start()
        // Give the server time to start
        Thread.sleep(forTimeInterval: 0.5)
    }

    override func tearDown() {
        server.stop()
        server = nil
        // Give the server time to release the port
        Thread.sleep(forTimeInterval: 0.3)
        super.tearDown()
    }

    // MARK: - Helpers

    private func sendRequest(method: String = "POST", path: String = "/notify", body: String? = nil, headers: [String: String] = [:]) -> (statusCode: Int, body: String)? {
        let expectation = XCTestExpectation(description: "HTTP request")
        nonisolated(unsafe) var resultStatus: Int = 0
        nonisolated(unsafe) var resultBody: String = ""

        guard let url = URL(string: "http://127.0.0.1:\(testPort)\(path)") else {
            XCTFail("Invalid URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                resultStatus = httpResponse.statusCode
            }
            if let data = data {
                resultBody = String(data: data, encoding: .utf8) ?? ""
            }
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
        return (resultStatus, resultBody)
    }

    // MARK: - Health Check

    func testHealthCheck() throws {
        let result = sendRequest(method: "GET", path: "/health")
        XCTAssertEqual(result?.statusCode, 200)
        XCTAssertTrue(result?.body.contains("\"status\":\"ok\"") ?? false)
    }

    // MARK: - POST /notify

    func testValidNotification() throws {
        let body = """
        {"title": "Test", "message": "Hello World"}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 200)
        XCTAssertTrue(result?.body.contains("\"success\":true") ?? false)
    }

    func testNotificationWithAllFields() throws {
        let body = """
        {"title": "Alert", "message": "Server down", "priority": 5, "tags": ["warning", "fire"]}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 200)
        XCTAssertTrue(result?.body.contains("\"success\":true") ?? false)
    }

    func testMissingTitle() throws {
        let body = """
        {"message": "No title here"}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 400)
        XCTAssertTrue(result?.body.contains("title") ?? false)
    }

    func testMissingMessage() throws {
        let body = """
        {"title": "No message"}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 400)
        XCTAssertTrue(result?.body.contains("message") ?? false)
    }

    func testEmptyTitle() throws {
        let body = """
        {"title": "", "message": "Hello"}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 400)
        XCTAssertTrue(result?.body.contains("title") ?? false)
    }

    func testEmptyMessage() throws {
        let body = """
        {"title": "Test", "message": ""}
        """
        let result = sendRequest(body: body)
        XCTAssertEqual(result?.statusCode, 400)
        XCTAssertTrue(result?.body.contains("message") ?? false)
    }

    func testInvalidJSON() throws {
        let result = sendRequest(body: "not json at all")
        XCTAssertEqual(result?.statusCode, 400)
        XCTAssertTrue(result?.body.contains("Invalid JSON") ?? false)
    }

    // MARK: - Wrong Path / Method

    func testWrongPath() throws {
        let result = sendRequest(method: "GET", path: "/wrong")
        XCTAssertEqual(result?.statusCode, 404)
    }

    func testGetOnNotify() throws {
        let result = sendRequest(method: "GET", path: "/notify")
        XCTAssertEqual(result?.statusCode, 404)
    }

    // MARK: - Browser Requests

    /// Browsers send Origin on every POST: a web page must not post notifications
    func testRejectsRequestWithOrigin() throws {
        let body = """
        {"title": "Test", "message": "Hello"}
        """
        let result = sendRequest(body: body, headers: ["Origin": "https://evil.example"])
        XCTAssertEqual(result?.statusCode, 403)
    }

    func testRejectsHealthCheckWithOrigin() throws {
        let result = sendRequest(method: "GET", path: "/health", headers: ["Origin": "null"])
        XCTAssertEqual(result?.statusCode, 403)
    }

    /// Scripts using `curl -d` without a JSON Content-Type keep working
    func testAcceptsFormContentTypeFromScripts() throws {
        let body = """
        {"title": "Test", "message": "Hello"}
        """
        let result = sendRequest(body: body, headers: ["Content-Type": "application/x-www-form-urlencoded"])
        XCTAssertEqual(result?.statusCode, 200)
    }

    func testBrowserRequestDetection() {
        // Local scripts
        XCTAssertFalse(server.isBrowserRequest(headers: "POST /notify HTTP/1.1\r\nHost: 127.0.0.1:9292"))
        XCTAssertFalse(server.isBrowserRequest(headers: "POST /notify HTTP/1.1\r\nhost: LOCALHOST:9292"))
        XCTAssertFalse(server.isBrowserRequest(headers: "POST /notify HTTP/1.0"))
        // Web pages, including one DNS-rebound to 127.0.0.1 under its own name
        XCTAssertTrue(server.isBrowserRequest(headers: "POST /notify HTTP/1.1\r\nHost: 127.0.0.1:9292\r\norigin: null"))
        XCTAssertTrue(server.isBrowserRequest(headers: "POST /notify HTTP/1.1\r\nHost: rebind.evil.example:9292"))
        // The request line is not a header
        XCTAssertFalse(server.isBrowserRequest(headers: "POST /origin: HTTP/1.1\r\nHost: localhost"))
    }
}
