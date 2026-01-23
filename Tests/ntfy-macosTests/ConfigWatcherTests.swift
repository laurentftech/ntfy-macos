import XCTest
@testable import ntfy_macos

final class ConfigWatcherTests: XCTestCase {
    var tempDir: URL!
    var tempConfigPath: String!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("configwatcher-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempConfigPath = tempDir.appendingPathComponent("config.yml").path

        // Create initial config file
        let initialConfig = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: test
        """
        try initialConfig.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testWatcherInitializesWithDefaultPath() {
        let watcher = ConfigWatcher()
        // Should not crash and use default path
        XCTAssertNotNil(watcher)
    }

    func testWatcherInitializesWithCustomPath() {
        let watcher = ConfigWatcher(configPath: tempConfigPath)
        XCTAssertNotNil(watcher)
    }

    func testWatcherCallsCallbackOnFileChange() throws {
        let watcher = ConfigWatcher(configPath: tempConfigPath)
        let expectation = XCTestExpectation(description: "Config change callback called")

        watcher.startWatching {
            expectation.fulfill()
        }

        // Give time for the watcher to set up
        Thread.sleep(forTimeInterval: 0.1)

        // Modify the config file
        let newConfig = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: updated
        """
        try newConfig.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        wait(for: [expectation], timeout: 2.0)
        watcher.stopWatching()
    }

    func testWatcherHandlesNonExistentFile() {
        let nonExistentPath = tempDir.appendingPathComponent("nonexistent.yml").path
        let watcher = ConfigWatcher(configPath: nonExistentPath)

        // Should not crash, just print a warning
        watcher.startWatching {
            XCTFail("Callback should not be called for non-existent file")
        }

        // Give time for any potential callbacks
        Thread.sleep(forTimeInterval: 0.2)
        watcher.stopWatching()
    }

    func testStopWatchingCanBeCalledMultipleTimes() {
        let watcher = ConfigWatcher(configPath: tempConfigPath)

        watcher.startWatching {}

        // Should not crash when called multiple times
        watcher.stopWatching()
        watcher.stopWatching()
        watcher.stopWatching()
    }

    func testWatcherHandlesFileRecreation() throws {
        let watcher = ConfigWatcher(configPath: tempConfigPath)
        let expectation = XCTestExpectation(description: "Config change callback after recreation")
        // At least one callback should be triggered after file recreation
        expectation.assertForOverFulfill = false

        watcher.startWatching {
            expectation.fulfill()
        }

        // Give time for the watcher to set up
        Thread.sleep(forTimeInterval: 0.1)

        // Delete and recreate the file (simulating atomic write)
        try FileManager.default.removeItem(atPath: tempConfigPath)

        // Wait for the watcher's 0.5s delay for file recreation
        Thread.sleep(forTimeInterval: 0.7)

        let newConfig = """
        servers:
          - url: https://ntfy.sh
            topics:
              - name: recreated
        """
        try newConfig.write(toFile: tempConfigPath, atomically: true, encoding: .utf8)

        wait(for: [expectation], timeout: 3.0)
        watcher.stopWatching()
    }

    func testWatcherStopsBeforeDeallocation() {
        var watcher: ConfigWatcher? = ConfigWatcher(configPath: tempConfigPath)
        watcher?.startWatching {}

        // Should not crash on deallocation
        watcher = nil

        // If we reach here without crashing, the test passes
        XCTAssertNil(watcher)
    }
}
