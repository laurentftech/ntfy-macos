import Foundation

/// Simple logger with timestamps
enum Log {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func info(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ❌ \(message)")
        fflush(stdout)
    }

    static func success(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ✅ \(message)")
        fflush(stdout)
    }
}
