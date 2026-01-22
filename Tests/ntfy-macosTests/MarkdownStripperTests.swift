import XCTest
@testable import ntfy_macos

final class MarkdownStripperTests: XCTestCase {

    func testStripBold() {
        XCTAssertEqual(MarkdownStripper.strip("**bold text**"), "bold text")
        XCTAssertEqual(MarkdownStripper.strip("__bold text__"), "bold text")
    }

    func testStripItalic() {
        XCTAssertEqual(MarkdownStripper.strip("*italic text*"), "italic text")
        XCTAssertEqual(MarkdownStripper.strip("_italic text_"), "italic text")
    }

    func testStripStrikethrough() {
        XCTAssertEqual(MarkdownStripper.strip("~~strikethrough~~"), "strikethrough")
    }

    func testStripInlineCode() {
        XCTAssertEqual(MarkdownStripper.strip("`code`"), "code")
        XCTAssertEqual(MarkdownStripper.strip("Use `git commit` to save"), "Use git commit to save")
    }

    func testStripCodeBlocks() {
        let markdown = """
        Before
        ```
        code block
        ```
        After
        """
        let result = MarkdownStripper.strip(markdown)
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
        XCTAssertFalse(result.contains("```"))
    }

    func testStripLinks() {
        XCTAssertEqual(MarkdownStripper.strip("[link text](https://example.com)"), "link text")
        XCTAssertEqual(MarkdownStripper.strip("Check [this](https://example.com) out"), "Check this out")
    }

    func testStripImages() {
        XCTAssertEqual(MarkdownStripper.strip("![alt text](https://example.com/image.png)"), "alt text")
    }

    func testStripHeaders() {
        XCTAssertEqual(MarkdownStripper.strip("# Header 1"), "Header 1")
        XCTAssertEqual(MarkdownStripper.strip("## Header 2"), "Header 2")
        XCTAssertEqual(MarkdownStripper.strip("### Header 3"), "Header 3")
    }

    func testStripBlockquotes() {
        XCTAssertEqual(MarkdownStripper.strip("> quoted text"), "quoted text")
    }

    func testStripUnorderedLists() {
        XCTAssertEqual(MarkdownStripper.strip("- item"), "item")
        XCTAssertEqual(MarkdownStripper.strip("* item"), "item")
        XCTAssertEqual(MarkdownStripper.strip("+ item"), "item")
    }

    func testStripOrderedLists() {
        XCTAssertEqual(MarkdownStripper.strip("1. first item"), "first item")
        XCTAssertEqual(MarkdownStripper.strip("2. second item"), "second item")
    }

    func testStripHorizontalRules() {
        let markdown = "Before\n---\nAfter"
        let result = MarkdownStripper.strip(markdown)
        XCTAssertFalse(result.contains("---"))
    }

    func testComplexMarkdown() {
        let markdown = "**Important**: Check [this link](https://example.com) for `details`"
        let expected = "Important: Check this link for details"
        XCTAssertEqual(MarkdownStripper.strip(markdown), expected)
    }

    func testPlainTextPassthrough() {
        let plainText = "This is just plain text with no markdown"
        XCTAssertEqual(MarkdownStripper.strip(plainText), plainText)
    }

    func testEmptyString() {
        XCTAssertEqual(MarkdownStripper.strip(""), "")
    }
}
