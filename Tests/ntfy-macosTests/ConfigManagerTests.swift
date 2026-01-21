import XCTest
@testable import ntfy_macos

final class ConfigManagerTests: XCTestCase {
    var tempConfigPath: String!

    override func setUp() {
        super.setUp()
        // Create a temporary file path for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempConfigPath = tempDir.appendingPathComponent("test-config-\(UUID().uuidString).yml").path
    }

    override func tearDown() {
        // Clean up temporary file
        if let path = tempConfigPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        super.tearDown()
    }

    // MARK: - Loading config

    func testLoadConfigFileNotFound() {
        let manager = ConfigManager.shared
        XCTAssertThrowsError(try manager.loadConfig(from: "/nonexistent/path/config.yml")) { error in
            if case ConfigError.fileNotFound = error {
                // Expected
            } else {
                XCTFail("Expected fileNotFound error, got \(error)")
            }
        }
    }

    func testLoadValidConfig() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
                icon_symbol: bell.fill
        """
        try yaml.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager.shared
        try manager.loadConfig(from: tempConfigPath)

        XCTAssertNotNil(manager.config)
        XCTAssertEqual(manager.config?.servers.count, 1)
        XCTAssertEqual(manager.config?.servers.first?.url, "https://ntfy.sh")
    }

    func testLoadConfigWithMultipleServers() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: public
                icon_symbol: globe
          - url: https://private.example.com
            token: secret123
            topics:
              - name: private
                icon_symbol: lock
        """
        try yaml.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager.shared
        try manager.loadConfig(from: tempConfigPath)

        XCTAssertEqual(manager.config?.servers.count, 2)
        XCTAssertEqual(manager.config?.allTopics.count, 2)
        XCTAssertEqual(manager.config?.servers[1].token, "secret123")
    }

    func testLoadInvalidYaml() throws {
        let invalidYaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: [invalid
        """
        try invalidYaml.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager.shared
        XCTAssertThrowsError(try manager.loadConfig(from: tempConfigPath))
    }

    // MARK: - Topic lookup

    func testTopicConfigLookup() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
                icon_symbol: bell.fill
                silent: true
              - name: news
                icon_symbol: newspaper
        """
        try yaml.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager.shared
        try manager.loadConfig(from: tempConfigPath)

        let alertsTopic = manager.topicConfig(for: "alerts")
        XCTAssertNotNil(alertsTopic)
        XCTAssertEqual(alertsTopic?.iconSymbol, "bell.fill")
        XCTAssertEqual(alertsTopic?.silent, true)

        let newsTopic = manager.topicConfig(for: "news")
        XCTAssertNotNil(newsTopic)
        XCTAssertEqual(newsTopic?.iconSymbol, "newspaper")

        let unknownTopic = manager.topicConfig(for: "nonexistent")
        XCTAssertNil(unknownTopic)
    }

    // MARK: - Sample config creation

    func testCreateSampleConfig() throws {
        let samplePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-config-\(UUID().uuidString).yml").path

        defer {
            try? FileManager.default.removeItem(atPath: samplePath)
        }

        try ConfigManager.createSampleConfig(at: samplePath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: samplePath))

        let content = try String(contentsOfFile: samplePath, encoding: .utf8)
        XCTAssertTrue(content.contains("servers:"))
        XCTAssertTrue(content.contains("topics:"))
        XCTAssertTrue(content.contains("ntfy.sh"))
    }

    func testCreateSampleConfigCreatesDirectory() throws {
        let nestedPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("nested-\(UUID().uuidString)")
            .appendingPathComponent("subdir")
            .appendingPathComponent("config.yml").path

        defer {
            // Clean up the entire nested directory
            let baseDir = (nestedPath as NSString).deletingLastPathComponent
            let parentDir = (baseDir as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: parentDir)
        }

        try ConfigManager.createSampleConfig(at: nestedPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath))
    }
}
