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

    func testMention() {
        let html = "<span class=\"account\" data-account-id=\"6\">@mention</span>"
        let expected = NSAttributedString(string: "@mention", attributes: Parser.mentionAttributes(forAccountID: "6"))
        XCTAssertEqual(makeAttributedString(fromHTML: html), expected)
    }

    func testHashTag() {
        let html = "<span class=\"hash\" data-hash=\"noagenda\">#noagenda</span>"
        let expected = NSAttributedString(string: "#noagenda", attributes: Parser.attributes(forHashTag: "noagenda"))
        XCTAssertEqual(makeAttributedString(fromHTML: html), expected)
    }

    func testBreak() {
        // We want a newline but not a new paragraph here. Not sure how to check that, but can check we get a new line.
        let html = "<p>Freelance tech writer<br /> Author<br /> Practical minimalist</p>"
        let result = makeAttributedString(fromHTML: html)

        let string = result.string
        let firstParagraphRange = string.paragraphRange(for: string.startIndex ..< string.index(after: string.startIndex))
        let wholeParagraphRange = string.startIndex ..< string.endIndex
        XCTAssertEqual(firstParagraphRange, wholeParagraphRange, "expected to render as a single paragraph")

        var lineCount = 0
        string.enumerateLines { (line, done) in
            lineCount += 1
        }
        XCTAssertEqual(lineCount, 3, "expected to render the single paragraph broken into 3 lines")
    }

    func SKIPPED_testHeaders() {
        // Blurbs don't support headers. Blog posts due, but not blurbs!
    }


    // MARK: - Renders block content
    func testOrderedList() {
        let html = "<ol><li>1</li><li>2</li></ol>"
        let expected = Parser.paragraphSeparator + "\t1. 1" + Parser.paragraphSeparator + "\t2. 2"
        XCTAssertEqual(makeAttributedString(fromHTML: html), NSAttributedString(string: expected))
    }

    func testUnorderedList() {
        let html = "<ul><li>A</li><li>B</li></ul>"
        let expected = Parser.paragraphSeparator + "\t• A" + Parser.paragraphSeparator + "\t• B"
        XCTAssertEqual(makeAttributedString(fromHTML: html), NSAttributedString(string: expected))
    }

    func SKIPPED_testNestedLists() {
        // AFAICT, Blurbs don't support nested lists. Now I'm curious about 10C blogpost Markdown…
        // Confirmed by @matigo not to support nested lists: https://10centuries.org/post/106230
    }

    func testListItemWithFootnoteClassSuperscriptsIndexAndOmitsDot() {
        let html = "<ol><li class=\"footnote\">footnote text</li></ol>"
        let result = makeAttributedString(fromHTML: html)

        XCTAssertNil(result.string.range(of: "."), "should not insert dot after footnote number, but got: \(result)")

        var encounteredSuperscript = false
        result.enumerateAttribute(superscriptAttributeName, in: NSRange(location: 0, length: result.length), options: []) { (value, range, done) in
            encounteredSuperscript = true
        }
        XCTAssertTrue(encounteredSuperscript, "should apply the attribute “\(superscriptAttributeName)” to the footnote number, but got: \(result)")
    }

    var superscriptAttributeName: String {
        #if os(macOS)
            return NSSuperscriptAttributeName
        #else
            return NSBaselineOffsetAttributeName
        #endif
    }

    func testAvoidsDoubleLinebreakDueToParagraphWithinListItem() {
        let html = "<ul><li><p>Single indent.</p></li></ul>"
        let expected = Parser.paragraphSeparator + "\t• Single indent."
        XCTAssertEqual(makeAttributedString(fromHTML: html), NSAttributedString(string: expected))
    }

    func testPreFormattedText() {
        let html = "<pre>this is    preformatted text</pre>"
        let expected = "this is    preformatted text"
        XCTAssertEqual(makeAttributedString(fromHTML: html), NSAttributedString(string: expected))
    }


    // MARK: - Renders decorations
    func testHorizontalRule() {
        // Think I'll just use an asterism in its own paragraph: ⁂
        let html = "<hr />"
        let expected = Parser.paragraphSeparator
        XCTAssertEqual(makeAttributedString(fromHTML: html), NSAttributedString(string: expected))
    }

    func testImageFormatsAsBracketedImageColonAndAltTextInItalics() {
        // Uses the NSAttachmentCharacter U+FFFC aka the replacement character (question mark in a diamond, often) as the text, and then injects the image using the attributes.
        // See: https://developer.apple.com/reference/uikit/nstextattachment#
        // But for now, I think I'll just show the ALT text. We'll have to sort out how to update these as the images arrive…
        let html = "<img src=\"unused\" alt=\"an image\" />"
        let expectedHTML = "<em>[Image: an image]</em>"
        XCTAssertEqual(makeAttributedString(fromHTML: html), makeAttributedString(fromHTML: expectedHTML))
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
