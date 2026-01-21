import XCTest
@testable import ntfy_macos

final class ScriptRunnerTests: XCTestCase {
    var runner: ScriptRunner!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        runner = ScriptRunner()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("script-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }

    // MARK: - Script Validation

    func testValidateScriptNotFound() {
        let result = runner.validateScript(at: "/nonexistent/path/script.sh")
        XCTAssertFalse(result)
    }

    func testValidateScriptIsDirectory() {
        let result = runner.validateScript(at: tempDir.path)
        XCTAssertFalse(result)
    }

    func testValidateScriptNotExecutable() throws {
        let scriptPath = tempDir.appendingPathComponent("not-executable.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)

        // File exists but is not executable
        let result = runner.validateScript(at: scriptPath.path)
        XCTAssertFalse(result)
    }

    func testValidateScriptExecutable() throws {
        let scriptPath = tempDir.appendingPathComponent("executable.sh")
        try "#!/bin/bash\necho hello".write(to: scriptPath, atomically: true, encoding: .utf8)

        // Make it executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.validateScript(at: scriptPath.path)
        XCTAssertTrue(result)
    }

    // MARK: - Script Execution

    func testRunScriptSynchronouslySimple() throws {
        let scriptPath = tempDir.appendingPathComponent("simple.sh")
        try "#!/bin/bash\necho 'Hello World'".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.runScriptSynchronously(at: scriptPath.path)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Hello World"))
        XCTAssertTrue(result.error.isEmpty)
    }

    func testRunScriptSynchronouslyWithArgument() throws {
        let scriptPath = tempDir.appendingPathComponent("with-arg.sh")
        try "#!/bin/bash\necho \"Received: $1\"".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.runScriptSynchronously(at: scriptPath.path, withArgument: "test-message")

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Received: test-message"))
    }

    func testRunScriptSynchronouslyExitCode() throws {
        let scriptPath = tempDir.appendingPathComponent("exit-code.sh")
        try "#!/bin/bash\nexit 42".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.runScriptSynchronously(at: scriptPath.path)

        XCTAssertEqual(result.exitCode, 42)
    }

    func testRunScriptSynchronouslyStderr() throws {
        let scriptPath = tempDir.appendingPathComponent("stderr.sh")
        try "#!/bin/bash\necho 'Error message' >&2".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.runScriptSynchronously(at: scriptPath.path)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.error.contains("Error message"))
    }

    func testRunScriptSynchronouslyNotFound() {
        let result = runner.runScriptSynchronously(at: "/nonexistent/script.sh")

        XCTAssertEqual(result.exitCode, -1)
        XCTAssertTrue(result.error.contains("Failed to execute"))
    }

    func testRunScriptWithEnvironmentPath() throws {
        // Test that the enhanced PATH is set
        let scriptPath = tempDir.appendingPathComponent("check-path.sh")
        try "#!/bin/bash\necho $PATH".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let result = runner.runScriptSynchronously(at: scriptPath.path)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("/opt/homebrew/bin"))
        XCTAssertTrue(result.output.contains("/usr/local/bin"))
    }

    // MARK: - Special Characters

    func testRunScriptWithSpecialCharactersInArgument() throws {
        let scriptPath = tempDir.appendingPathComponent("special-chars.sh")
        try "#!/bin/bash\necho \"Arg: $1\"".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let specialArg = "Hello 'World' with \"quotes\" and $pecial chars!"
        let result = runner.runScriptSynchronously(at: scriptPath.path, withArgument: specialArg)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("Hello"))
    }

    func testRunScriptWithUnicodeArgument() throws {
        let scriptPath = tempDir.appendingPathComponent("unicode.sh")
        try "#!/bin/bash\necho \"Message: $1\"".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let unicodeArg = "🔔 Notification: été, naïve, 日本語"
        let result = runner.runScriptSynchronously(at: scriptPath.path, withArgument: unicodeArg)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("🔔"))
    }
}
