import XCTest
@testable import ntfy_macos

final class NtfyErrorTests: XCTestCase {
    
    // MARK: - Config Errors Tests
    
    func testConfigNotFoundErrorDescription() {
        let error = NtfyError.configNotFound(path: "/path/to/config.yml")
        XCTAssertEqual(error.errorDescription, "Configuration file not found at: /path/to/config.yml")
    }
    
    func testConfigNotFoundRecoverySuggestion() {
        let error = NtfyError.configNotFound(path: "/path/to/config.yml")
        XCTAssertEqual(error.recoverySuggestion, "Run 'ntfy-macos init' to create a sample configuration")
    }
    
    func testConfigInvalidErrorDescription() {
        let error = NtfyError.configInvalid(reason: "YAML parsing failed")
        XCTAssertEqual(error.errorDescription, "Configuration is invalid: YAML parsing failed")
    }
    
    func testConfigValidationFailedErrorDescription() {
        let error = NtfyError.configValidationFailed(field: "server.url", reason: "Invalid URL")
        XCTAssertEqual(error.errorDescription, "Validation failed for 'server.url': Invalid URL")
    }
    
    func testUnknownConfigKeysErrorDescription() {
        let error = NtfyError.unknownConfigKeys("unknown_key")
        XCTAssertEqual(error.errorDescription, "Unknown configuration keys:\nunknown_key")
    }
    
    // MARK: - Keychain Errors Tests
    
    func testKeychainInvalidDataErrorDescription() {
        let error = NtfyError.keychainInvalidData
        XCTAssertEqual(error.errorDescription, "Invalid data provided for keychain operation")
    }
    
    func testKeychainItemNotFoundErrorDescription() {
        let error = NtfyError.keychainItemNotFound
        XCTAssertEqual(error.errorDescription, "Item not found in keychain")
    }
    
    func testKeychainItemNotFoundRecoverySuggestion() {
        let error = NtfyError.keychainItemNotFound
        XCTAssertEqual(error.recoverySuggestion, "Run 'ntfy-macos auth add <server> <token>' to store authentication")
    }
    
    func testKeychainUnexpectedStatusErrorDescription() {
        let error = NtfyError.keychainUnexpectedStatus(-50)
        XCTAssertEqual(error.errorDescription, "Keychain error: -50")
    }
    
    // MARK: - Server Errors Tests
    
    func testServerConnectionFailedWithErrorErrorDescription() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: nil)
        let error = NtfyError.serverConnectionFailed(url: "https://example.com", underlying: underlyingError)
        XCTAssertTrue(error.errorDescription!.contains("Failed to connect to https://example.com"))
        // Just verify there's an error description appended when underlying error exists
        XCTAssertTrue(error.errorDescription!.count > 40)
    }
    
    func testServerConnectionFailedWithoutErrorErrorDescription() {
        let error = NtfyError.serverConnectionFailed(url: "https://example.com", underlying: nil)
        XCTAssertEqual(error.errorDescription, "Failed to connect to https://example.com")
    }
    
    func testServerConnectionFailedRecoverySuggestion() {
        let error = NtfyError.serverConnectionFailed(url: "https://example.com", underlying: nil)
        XCTAssertEqual(error.recoverySuggestion, "Check your server URL and network connection")
    }
    
    func testServerAuthenticationFailedErrorDescription() {
        let error = NtfyError.serverAuthenticationFailed(url: "https://example.com")
        XCTAssertEqual(error.errorDescription, "Authentication failed for https://example.com")
    }
    
    func testServerAuthenticationFailedRecoverySuggestion() {
        let error = NtfyError.serverAuthenticationFailed(url: "https://example.com")
        XCTAssertEqual(error.recoverySuggestion, "Verify your authentication token with 'ntfy-macos auth list'")
    }
    
    func testServerTimeoutErrorDescription() {
        let error = NtfyError.serverTimeout(url: "https://example.com")
        XCTAssertEqual(error.errorDescription, "Connection timeout for https://example.com")
    }
    
    func testServerTimeoutRecoverySuggestion() {
        let error = NtfyError.serverTimeout(url: "https://example.com")
        XCTAssertEqual(error.recoverySuggestion, "Check if your server is reachable")
    }
    
    func testServerInvalidURLErrorDescription() {
        let error = NtfyError.serverInvalidURL(url: "not-a-url")
        XCTAssertEqual(error.errorDescription, "Invalid server URL: not-a-url")
    }
    
    func testServerInvalidURLRecoverySuggestion() {
        let error = NtfyError.serverInvalidURL(url: "not-a-url")
        XCTAssertEqual(error.recoverySuggestion, "URL must use http or https scheme")
    }
    
    // MARK: - Script Errors Tests
    
    func testScriptNotFoundErrorDescription() {
        let error = NtfyError.scriptNotFound(path: "/path/to/script.sh")
        XCTAssertEqual(error.errorDescription, "Script not found at: /path/to/script.sh")
    }
    
    func testScriptNotFoundRecoverySuggestion() {
        let error = NtfyError.scriptNotFound(path: "/path/to/script.sh")
        XCTAssertEqual(error.recoverySuggestion, "Verify the script path exists")
    }
    
    func testScriptNotExecutableErrorDescription() {
        let error = NtfyError.scriptNotExecutable(path: "/path/to/script.sh")
        XCTAssertEqual(error.errorDescription, "Script is not executable: /path/to/script.sh")
    }
    
    func testScriptNotExecutableRecoverySuggestion() {
        let error = NtfyError.scriptNotExecutable(path: "/path/to/script.sh")
        XCTAssertEqual(error.recoverySuggestion, "Run 'chmod +x <script-path>' to make the script executable")
    }
    
    func testScriptExecutionFailedErrorDescription() {
        let error = NtfyError.scriptExecutionFailed(path: "/path/to/script.sh", exitCode: 1)
        XCTAssertEqual(error.errorDescription, "Script '/path/to/script.sh' exited with code 1")
    }
    
    func testScriptTimeoutErrorDescription() {
        let error = NtfyError.scriptTimeout(path: "/path/to/script.sh")
        XCTAssertEqual(error.errorDescription, "Script timed out: /path/to/script.sh")
    }
    
    // MARK: - Notification Errors Tests
    
    func testNotificationPermissionDeniedErrorDescription() {
        let error = NtfyError.notificationPermissionDenied
        XCTAssertEqual(error.errorDescription, "Notification permission denied")
    }
    
    func testNotificationPermissionDeniedRecoverySuggestion() {
        let error = NtfyError.notificationPermissionDenied
        XCTAssertEqual(error.recoverySuggestion, "Enable notifications in System Settings → Notifications → ntfy-macos")
    }
    
    func testNotificationDeliveryFailedWithErrorErrorDescription() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: nil)
        let error = NtfyError.notificationDeliveryFailed(underlying: underlyingError)
        XCTAssertTrue(error.errorDescription!.contains("Notification delivery failed"))
        // Just verify there's an error description appended when underlying error exists
        XCTAssertTrue(error.errorDescription!.count > 35)
    }
    
    func testNotificationDeliveryFailedWithoutErrorErrorDescription() {
        let error = NtfyError.notificationDeliveryFailed(underlying: nil)
        XCTAssertEqual(error.errorDescription, "Notification delivery failed")
    }
    
    // MARK: - Local Server Errors Tests
    
    func testLocalServerPortInUseErrorDescription() {
        let error = NtfyError.localServerPortInUse(port: 9292)
        XCTAssertEqual(error.errorDescription, "Local server port 9292 is already in use")
    }
    
    func testLocalServerPortInUseRecoverySuggestion() {
        let error = NtfyError.localServerPortInUse(port: 9292)
        XCTAssertEqual(error.recoverySuggestion, "Choose a different port in your config.yml")
    }
    
    func testLocalServerFailedWithErrorErrorDescription() {
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: nil)
        let error = NtfyError.localServerFailed(port: 9292, underlying: underlyingError)
        XCTAssertTrue(error.errorDescription!.contains("Local server failed on port 9292"))
        // Just verify there's an error description appended when underlying error exists
        XCTAssertTrue(error.errorDescription!.count > 35)
    }
    
    func testLocalServerFailedWithoutErrorErrorDescription() {
        let error = NtfyError.localServerFailed(port: 9292, underlying: nil)
        XCTAssertEqual(error.errorDescription, "Local server failed on port 9292")
    }
    
    // MARK: - Error Conformance Tests
    
    func testErrorConformsToLocalizedError() {
        let error: Error = NtfyError.configNotFound(path: "/test")
        XCTAssertNotNil(error.localizedDescription)
    }
    
    func testErrorConformsToSendable() {
        // NtfyError is marked as Sendable, so it can be used across threads
        let error = NtfyError.configNotFound(path: "/test")
        // Just verify it compiles as Sendable
        let sendableError: NtfyError = error
        XCTAssertNotNil(sendableError)
    }
}
