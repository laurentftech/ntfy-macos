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

    // MARK: - Per-Server AllowedSchemes Tests

    func testServerAllowedSchemesDefaultsToHttpAndHttps() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertNil(server.allowedSchemes)
        XCTAssertEqual(server.effectiveAllowedSchemes, ["http", "https"])
    }

    func testServerAllowedSchemesCustomConfig() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_schemes:
          - http
          - https
          - ntfy
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertEqual(server.allowedSchemes, ["http", "https", "ntfy"])
        XCTAssertEqual(server.effectiveAllowedSchemes, ["http", "https", "ntfy"])
    }

    func testServerIsSchemeAllowedWithDefaultSchemes() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertTrue(server.isSchemeAllowed(URL(string: "https://example.com")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "http://example.com")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "HTTP://example.com")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "HTTPS://example.com")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "file:///etc/passwd")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "ftp://example.com")!))
    }

    func testServerIsSchemeAllowedWithCustomSchemes() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_schemes:
          - https
          - ntfy
          - myapp
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertTrue(server.isSchemeAllowed(URL(string: "https://example.com")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "ntfy://topic")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "myapp://action")!))
        XCTAssertTrue(server.isSchemeAllowed(URL(string: "NTFY://topic")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "http://example.com")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "file:///etc/passwd")!))
    }

    func testServerIsSchemeAllowedWithEmptySchemes() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_schemes: []
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertEqual(server.allowedSchemes, [])
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "https://example.com")!))
        XCTAssertFalse(server.isSchemeAllowed(URL(string: "http://example.com")!))
    }

    // MARK: - Per-Server AllowedDomains Tests

    func testServerAllowedDomainsNotConfigured() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertNil(server.allowedDomains)
        // When not configured, all domains are allowed
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://example.com")!))
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://evil.com")!))
    }

    func testServerAllowedDomainsExactMatch() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_domains:
          - example.com
          - trusted.org
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://example.com/path")!))
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://trusted.org")!))
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://EXAMPLE.COM")!))  // case insensitive
        XCTAssertFalse(server.isDomainAllowed(URL(string: "https://evil.com")!))
        XCTAssertFalse(server.isDomainAllowed(URL(string: "https://sub.example.com")!))  // subdomain not matched
    }

    func testServerAllowedDomainsWildcard() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_domains:
          - "*.example.com"
          - trusted.org
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://sub.example.com")!))
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://deep.sub.example.com")!))
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://example.com")!))  // base domain also matches
        XCTAssertTrue(server.isDomainAllowed(URL(string: "https://trusted.org")!))
        XCTAssertFalse(server.isDomainAllowed(URL(string: "https://evil.com")!))
        XCTAssertFalse(server.isDomainAllowed(URL(string: "https://example.com.evil.com")!))
    }

    func testServerAllowedDomainsEmpty() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_domains: []
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        // Empty list means no domains allowed (different from not configured)
        XCTAssertEqual(server.allowedDomains, [])
        XCTAssertFalse(server.isDomainAllowed(URL(string: "https://example.com")!))
    }

    func testServerIsUrlAllowedCombined() throws {
        let yaml = """
        url: https://ntfy.sh
        topics:
          - name: test
        allowed_schemes:
          - https
        allowed_domains:
          - example.com
        """
        let decoder = YAMLDecoder()
        let server = try decoder.decode(ServerConfig.self, from: yaml)

        XCTAssertTrue(server.isUrlAllowed(URL(string: "https://example.com")!))
        XCTAssertFalse(server.isUrlAllowed(URL(string: "http://example.com")!))  // wrong scheme
        XCTAssertFalse(server.isUrlAllowed(URL(string: "https://evil.com")!))    // wrong domain
        XCTAssertFalse(server.isUrlAllowed(URL(string: "http://evil.com")!))     // both wrong
    }

    // MARK: - AppConfig serverConfig(forTopic:) Tests

    func testAppConfigServerConfigForTopic() throws {
        let yaml = """
        servers:
          - url: https://server1.com
            topics:
              - name: topic1
          - url: https://server2.com
            allowed_schemes:
              - https
              - custom
            topics:
              - name: topic2
        """
        let decoder = YAMLDecoder()
        let config = try decoder.decode(AppConfig.self, from: yaml)

        let server1 = config.serverConfig(forTopic: "topic1")
        XCTAssertEqual(server1?.url, "https://server1.com")
        XCTAssertEqual(server1?.effectiveAllowedSchemes, ["http", "https"])

        let server2 = config.serverConfig(forTopic: "topic2")
        XCTAssertEqual(server2?.url, "https://server2.com")
        XCTAssertEqual(server2?.effectiveAllowedSchemes, ["https", "custom"])

        let serverNone = config.serverConfig(forTopic: "nonexistent")
        XCTAssertNil(serverNone)
    }

    // MARK: - Local Server Port Tests

    func testAppConfigWithLocalServerPort() throws {
        let yaml = """
        local_server_port: 9292
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
        """
        let decoder = YAMLDecoder()
        let config = try decoder.decode(AppConfig.self, from: yaml)

        XCTAssertEqual(config.localServerPort, 9292)
        XCTAssertEqual(config.servers.count, 1)
    }

    func testAppConfigWithoutLocalServerPort() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
        """
        let decoder = YAMLDecoder()
        let config = try decoder.decode(AppConfig.self, from: yaml)

        XCTAssertNil(config.localServerPort)
    }

    // MARK: - Config File Permissions Tests

    func testConfigErrorInsecurePermissionsDescription() throws {
        let error = ConfigError.insecureFilePermissions("Test message")
        if case .insecureFilePermissions(let message) = error {
            XCTAssertEqual(message, "Test message")
        } else {
            XCTFail("Expected insecureFilePermissions error")
        }
    }
}
