import Foundation

/// Represents the resolved action from a notification message.
/// This is used to determine what action to take when a user
/// interacts with a notification.
enum ResolvedAction: Equatable {
    case script(path: String)
    case view(url: URL)
    case none
}

/// Resolves the action to take from a `NtfyMessage`.
/// The resolver prioritizes actions in the following order:
/// 1. Script actions
/// 2. View (URL) actions
/// 3. The `click` URL on the message
final class NotificationActionResolver {

    func resolve(from message: NtfyMessage) -> ResolvedAction {
        if let actions = message.actions {
            // 1. Script actions (highest priority)
            for action in actions where action.action == "script" {
                if let urlString = action.url,
                   let url = validatedURL(from: urlString),
                   url.scheme == "file" {
                    return .script(path: url.path)
                }
            }

            // 2. View actions
            for action in actions where action.action == "view" {
                if let urlString = action.url,
                   let url = validatedURL(from: urlString) {
                    return .view(url: url)
                }
            }
        }

        // 3. Fallback to click URL
        if let clickURLString = message.click,
           let clickURL = validatedURL(from: clickURLString) {
            return .view(url: clickURL)
        }

        return .none
    }

    // MARK: - URL validation

    /// Validates URLs to avoid accepting malformed or unsafe strings.
    /// Only allows http, https and file schemes.
    private func validatedURL(from string: String) -> URL? {
        guard
            let url = URL(string: string),
            let scheme = url.scheme,
            ["http", "https", "file"].contains(scheme)
        else {
            return nil
        }
        return url
    }
}
