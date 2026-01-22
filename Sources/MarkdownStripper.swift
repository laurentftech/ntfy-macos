import Foundation

/// Strips markdown syntax from text for plain text display in notifications
enum MarkdownStripper {
    /// Strips common markdown syntax from text
    /// - Parameter text: The markdown text to strip
    /// - Returns: Plain text with markdown syntax removed
    static func strip(_ text: String) -> String {
        var result = text

        // Remove code blocks (``` ... ```)
        result = result.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )

        // Remove inline code (` ... `)
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "$1",
            options: .regularExpression
        )

        // Remove images ![alt](url)
        result = result.replacingOccurrences(
            of: "!\\[([^\\]]*)\\]\\([^)]+\\)",
            with: "$1",
            options: .regularExpression
        )

        // Remove links [text](url) -> text
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]+\\)",
            with: "$1",
            options: .regularExpression
        )

        // Remove bold **text** or __text__
        result = result.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "__([^_]+)__",
            with: "$1",
            options: .regularExpression
        )

        // Remove italic *text* or _text_
        result = result.replacingOccurrences(
            of: "(?<![*])\\*([^*]+)\\*(?![*])",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?<![_])_([^_]+)_(?![_])",
            with: "$1",
            options: .regularExpression
        )

        // Remove strikethrough ~~text~~
        result = result.replacingOccurrences(
            of: "~~([^~]+)~~",
            with: "$1",
            options: .regularExpression
        )

        // Remove headers (# ## ### etc.)
        result = result.replacingOccurrences(
            of: "^#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )
        // Also handle headers on multiple lines
        result = result.replacingOccurrences(
            of: "\n#{1,6}\\s+",
            with: "\n",
            options: .regularExpression
        )

        // Remove blockquotes (> text)
        result = result.replacingOccurrences(
            of: "^>\\s*",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\n>\\s*",
            with: "\n",
            options: .regularExpression
        )

        // Remove horizontal rules (---, ***, ___)
        result = result.replacingOccurrences(
            of: "^[-*_]{3,}$",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\n[-*_]{3,}\n",
            with: "\n",
            options: .regularExpression
        )

        // Remove unordered list markers (- or * or +)
        result = result.replacingOccurrences(
            of: "^[\\-*+]\\s+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\n[\\-*+]\\s+",
            with: "\n",
            options: .regularExpression
        )

        // Remove ordered list markers (1. 2. etc.)
        result = result.replacingOccurrences(
            of: "^\\d+\\.\\s+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\n\\d+\\.\\s+",
            with: "\n",
            options: .regularExpression
        )

        // Clean up multiple newlines
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}
