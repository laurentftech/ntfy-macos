import Foundation

/// Unified error type for ntfy-mac application
/// 
/// This enum provides consistent error handling across the entire application.
/// It includes cases for config, keychain, server, script, notification, and local server errors.
/// 
/// Note: ConfigError (in Config.swift) and KeychainError (in KeychainHelper.swift) are 
/// preserved separately for backward compatibility. This NtfyError can wrap those errors
/// when needed for unified error handling.
enum NtfyError: Error, LocalizedError, Sendable {
    // MARK: - Config Errors
    
    case configNotFound(path: String)
    case configInvalid(reason: String)
    case configValidationFailed(field: String, reason: String)
    case insecureFilePermissions(String)
    case unknownConfigKeys(String)
    
    // MARK: - Keychain Errors
    
    case keychainInvalidData
    case keychainItemNotFound
    case keychainUnexpectedStatus(OSStatus)
    
    // MARK: - Server Errors
    
    case serverConnectionFailed(url: String, underlying: Error?)
    case serverAuthenticationFailed(url: String)
    case serverTimeout(url: String)
    case serverInvalidURL(url: String)
    
    // MARK: - Script Errors
    
    case scriptNotFound(path: String)
    case scriptNotExecutable(path: String)
    case scriptExecutionFailed(path: String, exitCode: Int32)
    case scriptTimeout(path: String)
    
    // MARK: - Notification Errors
    
    case notificationPermissionDenied
    case notificationDeliveryFailed(underlying: Error?)
    
    // MARK: - Local Server Errors
    
    case localServerPortInUse(port: UInt16)
    case localServerFailed(port: UInt16, underlying: Error?)
    
    // MARK: - Error Description
    
    var errorDescription: String? {
        switch self {
        // Config errors
        case .configNotFound(let path):
            return "Configuration file not found at: \(path)"
        case .configInvalid(let reason):
            return "Configuration is invalid: \(reason)"
        case .configValidationFailed(let field, let reason):
            return "Validation failed for '\(field)': \(reason)"
        case .insecureFilePermissions(let message):
            return message
        case .unknownConfigKeys(let details):
            return "Unknown configuration keys:\n\(details)"
            
        // Keychain errors
        case .keychainInvalidData:
            return "Invalid data provided for keychain operation"
        case .keychainItemNotFound:
            return "Item not found in keychain"
        case .keychainUnexpectedStatus(let status):
            return "Keychain error: \(status)"
            
        // Server errors
        case .serverConnectionFailed(let url, let error):
            var message = "Failed to connect to \(url)"
            if let error = error {
                message += ": \(error.localizedDescription)"
            }
            return message
        case .serverAuthenticationFailed(let url):
            return "Authentication failed for \(url)"
        case .serverTimeout(let url):
            return "Connection timeout for \(url)"
        case .serverInvalidURL(let url):
            return "Invalid server URL: \(url)"
            
        // Script errors
        case .scriptNotFound(let path):
            return "Script not found at: \(path)"
        case .scriptNotExecutable(let path):
            return "Script is not executable: \(path)"
        case .scriptExecutionFailed(let path, let code):
            return "Script '\(path)' exited with code \(code)"
        case .scriptTimeout(let path):
            return "Script timed out: \(path)"
            
        // Notification errors
        case .notificationPermissionDenied:
            return "Notification permission denied"
        case .notificationDeliveryFailed(let error):
            var message = "Notification delivery failed"
            if let error = error {
                message += ": \(error.localizedDescription)"
            }
            return message
            
        // Local server errors
        case .localServerPortInUse(let port):
            return "Local server port \(port) is already in use"
        case .localServerFailed(let port, let error):
            var message = "Local server failed on port \(port)"
            if let error = error {
                message += ": \(error.localizedDescription)"
            }
            return message
        }
    }
    
    /// Recovery suggestion to help users resolve the error
    var recoverySuggestion: String? {
        switch self {
        case .configNotFound:
            return "Run 'ntfy-macos init' to create a sample configuration"
        case .configInvalid, .configValidationFailed:
            return "Check your config.yml file for syntax errors"
        case .insecureFilePermissions:
            return "Run 'chmod 600 ~/.config/ntfy-macos/config.yml' to secure your config file"
        case .unknownConfigKeys:
            return "Remove unknown keys from your config.yml"
        case .keychainItemNotFound:
            return "Run 'ntfy-macos auth add <server> <token>' to store authentication"
        case .keychainUnexpectedStatus:
            return "Check your Keychain access settings in System Settings"
        case .serverConnectionFailed:
            return "Check your server URL and network connection"
        case .serverAuthenticationFailed:
            return "Verify your authentication token with 'ntfy-macos auth list'"
        case .serverTimeout:
            return "Check if your server is reachable"
        case .serverInvalidURL:
            return "URL must use http or https scheme"
        case .scriptNotFound:
            return "Verify the script path exists"
        case .scriptNotExecutable:
            return "Run 'chmod +x <script-path>' to make the script executable"
        case .notificationPermissionDenied:
            return "Enable notifications in System Settings → Notifications → ntfy-macos"
        case .localServerPortInUse:
            return "Choose a different port in your config.yml"
        default:
            return nil
        }
    }
}
