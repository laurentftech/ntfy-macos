import XCTest
@testable import ntfy_macos

final class RetryAfterTests: XCTestCase {
    var client: NtfyClient!

    override func setUp() {
        super.setUp()
        client = NtfyClient(serverURL: "https://ntfy.sh", topics: ["test"])
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    // MARK: - Seconds format

    func testParseRetryAfterSeconds() {
        XCTAssertEqual(client.parseRetryAfter("60"), 60.0)
        XCTAssertEqual(client.parseRetryAfter("120"), 120.0)
        XCTAssertEqual(client.parseRetryAfter("300"), 300.0)
    }

    func testParseRetryAfterSecondsMinimum() {
        // Should return at least 1 second
        XCTAssertEqual(client.parseRetryAfter("0"), 1.0)
        XCTAssertEqual(client.parseRetryAfter("-10"), 1.0)
    }

    func testParseRetryAfterDecimalSeconds() {
        XCTAssertEqual(client.parseRetryAfter("30.5"), 30.5)
    }

    // MARK: - HTTP date format (IMF-fixdate)

    func testParseRetryAfterIMFFixdate() {
        // Create a date 60 seconds in the future
        let futureDate = Date().addingTimeInterval(60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        let dateString = formatter.string(from: futureDate)
        let result = client.parseRetryAfter(dateString)

        // Should be approximately 60 seconds (allow 2 second margin for test execution)
        XCTAssertGreaterThan(result, 58.0)
        XCTAssertLessThan(result, 62.0)
    }

    func testParseRetryAfterPastDate() {
        // Past date should return minimum of 1 second
        let result = client.parseRetryAfter("Sun, 01 Jan 2020 00:00:00 GMT")
        XCTAssertEqual(result, 1.0)
    }

    // MARK: - Invalid format

    func testParseRetryAfterInvalidFormat() {
        // Invalid format should return fallback of 30 seconds
        XCTAssertEqual(client.parseRetryAfter("invalid"), 30.0)
        XCTAssertEqual(client.parseRetryAfter(""), 30.0)
        XCTAssertEqual(client.parseRetryAfter("not-a-date"), 30.0)
    }

    // MARK: - Edge cases

    func testParseRetryAfterWithWhitespace() {
        // Whitespace might cause parsing issues
        XCTAssertEqual(client.parseRetryAfter(" 60 "), 30.0)  // Fails to parse, returns fallback
    }

    func testParseRetryAfterLargeValue() {
        XCTAssertEqual(client.parseRetryAfter("3600"), 3600.0)  // 1 hour
        XCTAssertEqual(client.parseRetryAfter("86400"), 86400.0)  // 1 day
    }
}
