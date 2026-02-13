import XCTest
@testable import ntfy_macos

final class ConfigValidatorTests: XCTestCase {
    
    // MARK: - URL Validation Tests
    
    func testValidateServerURLWithValidHTTP() throws {
        let url = "http://example.com"
        try ConfigValidator.validateServerURL(url)
        // Should not throw
    }
    
    func testValidateServerURLWithValidHTTPS() throws {
        let url = "https://example.com"
        try ConfigValidator.validateServerURL(url)
        // Should not throw
    }
    
    func testValidateServerURLWithInvalidScheme() {
        let url = "ftp://example.com"
        XCTAssertThrowsError(try ConfigValidator.validateServerURL(url)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateServerURLWithInvalidFormat() {
        let url = "not-a-url"
        XCTAssertThrowsError(try ConfigValidator.validateServerURL(url)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateServerURLWithEmptyHost() {
        let url = "http://"
        XCTAssertThrowsError(try ConfigValidator.validateServerURL(url)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateServerURLWithIPAddress() throws {
        let url = "http://192.168.1.1"
        try ConfigValidator.validateServerURL(url)
        // Should not throw
    }
    
    func testValidateServerURLWithPort() throws {
        let url = "https://example.com:8080"
        try ConfigValidator.validateServerURL(url)
        // Should not throw
    }
    
    // MARK: - Full Config Validation Tests
    
    func testValidateWithValidConfig() throws {
        let config = AppConfig(
            servers: [
                ServerConfig(
                    url: "https://ntfy.sh",
                    topics: [TopicConfig(name: "test-topic")]
                )
            ]
        )
        try ConfigValidator.validate(config)
        // Should not throw
    }
    
    func testValidateWithInvalidServerURL() {
        let config = AppConfig(
            servers: [
                ServerConfig(
                    url: "ftp://invalid",
                    topics: [TopicConfig(name: "test-topic")]
                )
            ]
        )
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateWithNoTopics() {
        let config = AppConfig(
            servers: [
                ServerConfig(
                    url: "https://ntfy.sh",
                    topics: []
                )
            ]
        )
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateWithDuplicateTopicNames() {
        let config = AppConfig(
            servers: [
                ServerConfig(
                    url: "https://ntfy.sh",
                    topics: [
                        TopicConfig(name: "duplicate"),
                        TopicConfig(name: "duplicate")
                    ]
                )
            ]
        )
        XCTAssertThrowsError(try ConfigValidator.validate(config)) { error in
            XCTAssertTrue(error is ConfigError)
        }
    }
    
    func testValidateWithMultipleServers() throws {
        let config = AppConfig(
            servers: [
                ServerConfig(
                    url: "https://server1.example.com",
                    topics: [TopicConfig(name: "topic1")]
                ),
                ServerConfig(
                    url: "https://server2.example.com",
                    topics: [TopicConfig(name: "topic2")]
                )
            ]
        )
        try ConfigValidator.validate(config)
        // Should not throw
    }
}
