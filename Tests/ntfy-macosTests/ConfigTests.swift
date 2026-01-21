import XCTest
import Yams
@testable import ntfy_macos

final class ConfigTests: XCTestCase {
    func testClickUrlConfigDecodingBoolTrue() throws {
        let yaml = "true"
        let decoder = YAMLDecoder()
        let result = try decoder.decode(ClickUrlConfig.self, from: yaml)
        if case .enabled = result {
            // Success
        } else {
            XCTFail("Expected .enabled, got \(result)")
        }
    }

    func testClickUrlConfigDecodingBoolFalse() throws {
        let yaml = "false"
        let decoder = YAMLDecoder()
        let result = try decoder.decode(ClickUrlConfig.self, from: yaml)
        if case .disabled = result {
            // Success
        } else {
            XCTFail("Expected .disabled, got \(result)")
        }
    }

    func testClickUrlConfigDecodingCustomUrl() throws {
        let yaml = "\"https://example.com\""
        let decoder = YAMLDecoder()
        let result = try decoder.decode(ClickUrlConfig.self, from: yaml)
        if case .custom(let url) = result {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .custom, got \(result)")
        }
    }

    func testTopicConfigDecoding() throws {
        let yaml = """
        name: alerts
        icon_symbol: bell.fill
        silent: true
        click_url: false
        """
        let decoder = YAMLDecoder()
        let topic = try decoder.decode(TopicConfig.self, from: yaml)

        XCTAssertEqual(topic.name, "alerts")
        XCTAssertEqual(topic.iconSymbol, "bell.fill")
        XCTAssertEqual(topic.silent, true)
        XCTAssertNil(topic.iconPath)
        XCTAssertNil(topic.autoRunScript)

        if case .disabled = topic.clickUrl {
            // Success
        } else {
            XCTFail("Expected click_url to be .disabled")
        }
    }

    func testServerConfigDecoding() throws {
        let yaml = """
        url: https://ntfy.sh
        token: my_token
        topics:
          - name: topic1
            icon_symbol: bell
          - name: topic2
            icon_path: /path/to/icon.png
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertEqual(server.url, "https://ntfy.sh")
        XCTAssertEqual(server.token, "my_token")
        XCTAssertEqual(server.topics.count, 2)
        XCTAssertEqual(server.topics[0].name, "topic1")
        XCTAssertEqual(server.topics[1].name, "topic2")
    }

    func testAppConfigDecoding() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
                icon_symbol: bell
          - url: https://private.ntfy.com
            token: secret
            topics:
              - name: private
                icon_symbol: lock
        """
        let decoder = YAMLDecoder()
        let config = try decoder.decode(AppConfig.self, from: yaml)

        XCTAssertEqual(config.servers.count, 2)
        XCTAssertEqual(config.allTopics.count, 2)
        XCTAssertEqual(config.servers[0].url, "https://ntfy.sh")
        XCTAssertEqual(config.servers[1].token, "secret")
    }

    func testNotificationActionDecoding() throws {
        let yaml = """
        name: test
        actions:
          - title: Run Script
            type: script
            path: /usr/local/bin/test.sh
          - title: Open URL
            type: view
            url: https://example.com
        """
        let decoder = YAMLDecoder()
        let topic = try decoder.decode(TopicConfig.self, from: yaml)

        XCTAssertEqual(topic.actions?.count, 2)
        XCTAssertEqual(topic.actions?[0].title, "Run Script")
        XCTAssertEqual(topic.actions?[0].type, "script")
        XCTAssertEqual(topic.actions?[0].path, "/usr/local/bin/test.sh")
        XCTAssertEqual(topic.actions?[1].title, "Open URL")
        XCTAssertEqual(topic.actions?[1].type, "view")
        XCTAssertEqual(topic.actions?[1].url, "https://example.com")
    }
}
