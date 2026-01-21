import XCTest
@testable import ntfy_macos

final class EmojiTagsTests: XCTestCase {
    func testEmojiPrefixWithValidTags() {
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["warning"]), "⚠️ ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["fire"]), "🔥 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["rocket"]), "🚀 ")
    }

    func testEmojiPrefixWithMultipleTags() {
        let result = EmojiTags.emojiPrefix(for: ["warning", "fire"])
        XCTAssertEqual(result, "⚠️🔥 ")
    }

    func testEmojiPrefixWithNilTags() {
        XCTAssertEqual(EmojiTags.emojiPrefix(for: nil), "")
    }

    func testEmojiPrefixWithEmptyTags() {
        XCTAssertEqual(EmojiTags.emojiPrefix(for: []), "")
    }

    func testEmojiPrefixWithUnknownTags() {
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["unknown_tag_xyz"]), "")
    }

    func testEmojiPrefixWithMixedKnownAndUnknownTags() {
        let result = EmojiTags.emojiPrefix(for: ["warning", "unknown_tag", "fire"])
        XCTAssertEqual(result, "⚠️🔥 ")
    }

    func testEmojiPrefixIsCaseInsensitive() {
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["WARNING"]), "⚠️ ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["Fire"]), "🔥 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["ROCKET"]), "🚀 ")
    }

    func testCommonEmojis() {
        // Test a variety of commonly used emojis
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["white_check_mark"]), "✅ ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["x"]), "❌ ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["bell"]), "🔔 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["thumbsup"]), "👍 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["+1"]), "👍 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["tada"]), "🎉 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["computer"]), "💻 ")
        XCTAssertEqual(EmojiTags.emojiPrefix(for: ["email"]), "📧 ")
    }
}
