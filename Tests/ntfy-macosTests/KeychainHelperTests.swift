import XCTest
@testable import ntfy_macos

final class KeychainHelperTests: XCTestCase {
    let testServer = "https://test.ntfy.sh"
    let testToken1 = "test_token_1"
    let testToken2 = "test_token_2"
    let testServer2 = "https://test2.ntfy.sh"


    override func setUp() {
        super.setUp()
        // Be sure no tokens are present before a test
        try? KeychainHelper.deleteToken(forServer: testServer)
        try? KeychainHelper.deleteToken(forServer: testServer2)
    }

    override func tearDown() {
        // Clean up any keychain items created during tests
        try? KeychainHelper.deleteToken(forServer: testServer)
        try? KeychainHelper.deleteToken(forServer: testServer2)
        super.tearDown()
    }

    func testSaveAndGetToken() throws {
        // 1. Save token
        try KeychainHelper.saveToken(testToken1, forServer: testServer)

        // 2. Retrieve token
        let retrievedToken = try KeychainHelper.getToken(forServer: testServer)

        // 3. Verify
        XCTAssertEqual(retrievedToken, testToken1)
    }

    func testUpdateToken() throws {
        // 1. Save initial token
        try KeychainHelper.saveToken(testToken1, forServer: testServer)

        // 2. Update with a new token
        try KeychainHelper.saveToken(testToken2, forServer: testServer)

        // 3. Retrieve token
        let retrievedToken = try KeychainHelper.getToken(forServer: testServer)

        // 4. Verify it's the new token
        XCTAssertEqual(retrievedToken, testToken2)
    }

    func testGetNonexistentToken() {
        XCTAssertThrowsError(try KeychainHelper.getToken(forServer: "nonexistent.server.com")) { error in
            guard let keychainError = error as? KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            if case .itemNotFound = keychainError {
                // Expected error
            } else {
                XCTFail("Expected .itemNotFound, got \(keychainError)")
            }
        }
    }

    func testDeleteToken() throws {
        // 1. Save a token
        try KeychainHelper.saveToken(testToken1, forServer: testServer)

        // 2. Make sure it's there
        XCTAssertNoThrow(try KeychainHelper.getToken(forServer: testServer))

        // 3. Delete it
        try KeychainHelper.deleteToken(forServer: testServer)

        // 4. Verify it's gone
        XCTAssertThrowsError(try KeychainHelper.getToken(forServer: testServer)) { error in
            if case .itemNotFound = error as? KeychainError {
                // Expected
            } else {
                XCTFail("Expected itemNotFound error after deletion")
            }
        }
    }

    func testListServers() throws {
        // 1. Get initial state
        let serversBefore = (try? KeychainHelper.listServers()) ?? []

        // 2. Add test-specific servers that are cleaned up by tearDown
        try KeychainHelper.saveToken("token1", forServer: testServer)
        try KeychainHelper.saveToken("token2", forServer: testServer2)

        // 3. Get new state
        let serversAfterAdd = try KeychainHelper.listServers()

        // 4. Assert that count increased by 2 and new servers are present
        XCTAssertEqual(serversAfterAdd.count, serversBefore.count + 2)
        XCTAssertTrue(serversAfterAdd.contains(testServer))
        XCTAssertTrue(serversAfterAdd.contains(testServer2))

        // 5. Delete one server
        try KeychainHelper.deleteToken(forServer: testServer)
        let serversAfterOneDelete = try KeychainHelper.listServers()

        // 6. Assert count decreased by 1 and server is gone
        XCTAssertEqual(serversAfterOneDelete.count, serversBefore.count + 1)
        XCTAssertFalse(serversAfterOneDelete.contains(testServer))
        XCTAssertTrue(serversAfterOneDelete.contains(testServer2))

        // 7. Delete the other server
        try KeychainHelper.deleteToken(forServer: testServer2)
        let serversAfterBothDelete = try KeychainHelper.listServers()

        // 8. Assert we are back to the initial state (order doesn't matter)
        XCTAssertEqual(Set(serversAfterBothDelete), Set(serversBefore))
    }
}
