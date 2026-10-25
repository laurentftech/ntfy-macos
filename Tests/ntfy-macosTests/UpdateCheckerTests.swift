import XCTest
import Yams
@testable import ntfy_macos

final class UpdateCheckerTests: XCTestCase {
    // MARK: - Version Parsing

    func testParseVersionPlain() {
        XCTAssertEqual(UpdateChecker.parseVersion("1.2.6"), [1, 2, 6])
    }

    func testParseVersionWithPrefix() {
        XCTAssertEqual(UpdateChecker.parseVersion("v1.2.6"), [1, 2, 6])
    }

    func testParseVersionRejectsNonNumeric() {
        XCTAssertNil(UpdateChecker.parseVersion("dev"))
        XCTAssertNil(UpdateChecker.parseVersion("1.3.0-beta"))
        XCTAssertNil(UpdateChecker.parseVersion("1..2"))
        XCTAssertNil(UpdateChecker.parseVersion(""))
    }

    // MARK: - Version Comparison

    func testNewerPatchVersion() {
        XCTAssertTrue(UpdateChecker.isVersion("v1.2.7", newerThan: "1.2.6"))
    }

    func testNumericNotLexicographicComparison() {
        XCTAssertTrue(UpdateChecker.isVersion("v1.10.0", newerThan: "1.9.9"))
    }

    func testSameVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isVersion("v1.2.6", newerThan: "1.2.6"))
    }

    func testOlderVersionIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isVersion("v1.2.5", newerThan: "1.2.6"))
    }

    func testMissingComponentsTreatedAsZero() {
        XCTAssertFalse(UpdateChecker.isVersion("v1.3", newerThan: "1.3.0"))
        XCTAssertTrue(UpdateChecker.isVersion("v1.3.1", newerThan: "1.3"))
    }

    func testUnparseableVersionsAreNeverNewer() {
        XCTAssertFalse(UpdateChecker.isVersion("v2.0.0", newerThan: "dev"))
        XCTAssertFalse(UpdateChecker.isVersion("garbage", newerThan: "1.2.6"))
    }

    // MARK: - Release Decoding

    func testDecodeGitHubRelease() throws {
        let json = """
        {"tag_name": "v1.2.7", "html_url": "https://github.com/laurentftech/ntfy-macos/releases/tag/v1.2.7", "draft": false}
        """
        let release = try JSONDecoder().decode(UpdateChecker.Release.self, from: Data(json.utf8))
        XCTAssertEqual(release.tagName, "v1.2.7")
        XCTAssertEqual(release.htmlUrl, "https://github.com/laurentftech/ntfy-macos/releases/tag/v1.2.7")
    }

    // MARK: - Config

    func testCheckForUpdatesDefaultsToTrue() throws {
        let yaml = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
        """
        let config = try YAMLDecoder().decode(AppConfig.self, from: yaml)
        XCTAssertNil(config.checkForUpdates)
        XCTAssertTrue(config.shouldCheckForUpdates)
    }

    func testCheckForUpdatesCanBeDisabled() throws {
        let yaml = """
        check_for_updates: false
        servers:
          - url: https://ntfy.sh
            topics:
              - name: alerts
        """
        let config = try YAMLDecoder().decode(AppConfig.self, from: yaml)
        XCTAssertFalse(config.shouldCheckForUpdates)
    }
}
