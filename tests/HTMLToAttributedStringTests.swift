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
        assertSymbolicTraits(.traitItalic, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testBoldWord() {
        let html = "<strong>bold</strong>"
        let result = makeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitBold, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testCodeWord() {
        let html = "<code>code</code>"
        let result = makeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitMonoSpace, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testSuperscriptNumber() {
        let html = "<sup>1</sup>"
        let result = makeAttributedString(fromHTML: html)

        #if os(macOS)
            guard let superscript = result.attribute(NSSuperscriptAttributeName, at: 0, effectiveRange: nil) else {
                return XCTFail("failed to set superscript attribute at index 0 in attributed string: \(result)")
            }
            return
        #endif

        // Workaround for not having the superscript attribute: Raise the text a bit.
        // See: https://stackoverflow.com/questions/21415963/nsattributedstring-superscript-styling
        guard let baselineOffset = result.attribute(NSBaselineOffsetAttributeName, at: 0, effectiveRange: nil) as? CGFloat else {
            return XCTFail("failed to set baseline attribute at index 0 in attributed string: \(result)")
        }
        XCTAssertTrue(baselineOffset > 0, "expected baseline offset greater than zero, but found: \(baselineOffset)")
    }

    func testStrikethroughWord() {
        let html = "<strike>strike</strike>"
        let result = makeAttributedString(fromHTML: html)
        XCTAssertNotNil(
            result.attribute(NSStrikethroughStyleAttributeName, at: 0, effectiveRange: nil),
            "expected to find strikethrough attribute at index 0 of attributed string: \(result)")
    }

    func testAnchorWord() {
        let html = "<a target=\"_blank\" href=\"http://example.com\" title=\"ignored\">anchored</a>"
        let result = makeAttributedString(fromHTML: html)
        guard let link = result.attribute(NSLinkAttributeName, at: 0, effectiveRange: nil) else {
            return XCTFail("expected to find link attribute at index 0 of attributed string: \(result)")
        }

        XCTAssertEqual(link as? String, "http://example.com", "failed to correctly populate link attribute, or not a string: \(String(reflecting: link))")
    }

    func testHeaders() {
        // (jeremy-w/2017-01-22)TODO: Try this in 10C and see what shakes out. Does it handle H1-H6? More?
    }

    func testMention() {
        let html = "<span class=\"account\" data-account-id=\"6\">@mention</span>"
    }

    func testHash() {
        let html = "<span class=\"hash\" data-hash=\"noagenda\">#noagenda</span>"
    }

    func testBreak() {
        // We want a newline but not a new paragraph here. Not sure how to check that, but can check we get a new line.
        let html = "<p>Freelance tech writer<br /> Author<br /> Practical minimalist</p>"
    }


    // MARK: - Renders block content
    func testOrderedList() {
        // Looks like we'll have to render these ourselves. What fun.
    }

    func testUnorderedList() {
        // Looks like we'll have to render these ourselves. What fun.
    }

    func testPreFormattedText() {
        // Should cause us to actually include otherwise-insignificant whitespace.
    }


    // MARK: - Renders decorations
    func testHorizontalRule() {
        // Think I'll just use an asterism: ⁂
    }

    func testImage() {
        // Uses the NSAttachmentCharacter U+FFFC aka the replacement character (question mark in a diamond, often) as the text.
    }

    func assertSymbolicTraits(_ trait: UIFontDescriptorSymbolicTraits, foundInFontDescriptorAtIndex index: Int, of string: NSAttributedString, file: StaticString = #file, line: UInt = #line) {
        guard let font = string.attribute(NSFontAttributeName, at: index, effectiveRange: nil) as? UIFont else {
            return XCTFail("failed to set font attribute at index \(index) in attributed string: \(string)", file: file, line: line)
        }

        XCTAssertTrue(
            font.fontDescriptor.symbolicTraits.contains(trait),
            "expected symbolic traits to contain \(trait) for font \(font) with descriptor \(font.fontDescriptor)", file: file, line: line)
    }
}
