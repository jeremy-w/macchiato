import XCTest
@testable import Macchiato

class HTMLToAttributedStringTests: XCTestCase {
    func testPlainTextSingleParagraph() {
        let html = "<p>plain text</p>"
        let expected = NSAttributedString(string: "plain text")
        XCTAssertEqual(makeAttributedString(fromHTML: html), expected)
    }


    // MARK: - Renders inline styles
    func testPlainTextTwoParagraphs() {
        let html = "<body><p>one</p><p>two</p></body>"
        let expected = NSAttributedString(string:
            "one\r\n"
            + "two")
        XCTAssertEqual(makeAttributedString(fromHTML: html), expected)
    }

    func testItalicWord() {
        let html = "<em>italic</em>"
        let result = makeAttributedString(fromHTML: html)
        guard let font = result.attribute(NSFontAttributeName, at: 0, effectiveRange: nil) as? UIFont else {
            return XCTFail("failed to set font attribute in attributed string: \(result)")
        }

        XCTAssertTrue(
            font.fontDescriptor.symbolicTraits.contains(.traitItalic),
            "expected symbolic traits to contain “Italic” for font \(font) with descriptor \(font.fontDescriptor)")
    }

    func testBoldWord() {
        let html = "<strong>bold</strong>"
    }

    func testCodeWord() {
        let html = "<code>code</code>"
    }

    func testSuperscriptNumber() {
        let html = "<sup>1</sup>"
    }

    func testStrikethroughWord() {
        let html = "<strike>strike</strike>"
    }

    func testAnchorWord() {
    }


    // MARK: - Renders block content
    func testOrderedList() {
    }

    func testUnorderedList() {
    }

    func testPreFormattedText() {
    }

    func testPreFormattedCode() {
    }


    // MARK: - Renders decorations
    func testHorizontalRule() {
    }

    func testImage() {
    }
}
