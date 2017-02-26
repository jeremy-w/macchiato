import XCTest
@testable import Macchiato

class HTMLToAttributedStringTests: XCTestCase {
    func testPlainTextSingleParagraph() {
        let html = "<p>plain text</p>"
        let expected = NSAttributedString(string: "plain text", attributes: TenCenturiesHTMLParser.paragraph)
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), expected)
    }

    func shouldMakeAttributedString(fromHTML html: String) -> NSAttributedString {
        guard let result = makeAttributedString(fromHTML: html) else {
            XCTFail("failed to build attributed string from: \(html)")
            return NSAttributedString()
        }
        return result
    }


    // MARK: - Renders inline styles
    func testPlainTextTwoParagraphs() {
        let html = "<body><p>one</p><p>two</p></body>"
        let expected = NSAttributedString(string:
            "one\r\n\r\n"
            + "two", attributes: TenCenturiesHTMLParser.paragraph)
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), expected)
    }

    func testItalicWord() {
        let html = "<em>italic</em>"
        let result = shouldMakeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitItalic, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testBoldWord() {
        let html = "<strong>bold</strong>"
        let result = shouldMakeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitBold, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testCodeWord() {
        let html = "<code>code</code>"
        let result = shouldMakeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitMonoSpace, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testSuperscriptNumber() {
        let html = "<sup>1</sup>"
        let result = shouldMakeAttributedString(fromHTML: html)

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
        let result = shouldMakeAttributedString(fromHTML: html)
        XCTAssertNotNil(
            result.attribute(NSStrikethroughStyleAttributeName, at: 0, effectiveRange: nil),
            "expected to find strikethrough attribute at index 0 of attributed string: \(result)")
    }

    func testAnchorWord() {
        let html = "<a target=\"_blank\" href=\"http://example.com\" title=\"ignored\">anchored</a>"
        let result = shouldMakeAttributedString(fromHTML: html)
        guard let link = result.attribute(NSLinkAttributeName, at: 0, effectiveRange: nil) else {
            return XCTFail("expected to find link attribute at index 0 of attributed string: \(result)")
        }

        XCTAssertEqual(link as? String, "http://example.com", "failed to correctly populate link attribute, or not a string: \(String(reflecting: link))")
    }

    func testMention() {
        let html = "<span class=\"account\" data-account-id=\"6\">@mention</span>"
        let expected = NSAttributedString(string: "@mention", attributes: TenCenturiesHTMLParser.applyMentionAttributes(forAccountID: "6", to: TenCenturiesHTMLParser.paragraph))
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), expected)
    }

    func testHashTag() {
        let html = "<span class=\"hash\" data-hash=\"noagenda\">#noagenda</span>"
        let expected = NSAttributedString(string: "#noagenda", attributes: TenCenturiesHTMLParser.applyAttributes(forHashtag: "noagenda", to: TenCenturiesHTMLParser.paragraph))
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), expected)
    }

    func testBreak() {
        // We want a newline but not a new paragraph here. Not sure how to check that, but can check we get a new line.
        let html = "<p>Freelance tech writer<br /> Author<br /> Practical minimalist</p>"
        let result = shouldMakeAttributedString(fromHTML: html)

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
        // Blurbs don't support headers. Blog posts do, but not blurbs!
    }


    // MARK: - Handles stacked styles
    func testBoldItalic() {
        let html = "<strong><em>bold and italic</em></strong>"
        let result = shouldMakeAttributedString(fromHTML: html)
        assertSymbolicTraits(.traitBold, foundInFontDescriptorAtIndex: 0, of: result)
        assertSymbolicTraits(.traitItalic, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testBoldItalicIsSameAsItalicBold() {
        XCTAssertEqual(
            shouldMakeAttributedString(fromHTML: "<strong><em>bi</em></strong>"),
            shouldMakeAttributedString(fromHTML: "<em><strong>bi</strong></em>"))
    }

    func testBoldCode() {
        let result = shouldMakeAttributedString(fromHTML: "<strong><code>tt</code></strong>")
        assertSymbolicTraits(.traitBold, foundInFontDescriptorAtIndex: 0, of: result)
        assertSymbolicTraits(.traitMonoSpace, foundInFontDescriptorAtIndex: 0, of: result)
    }

    func testHyperlinkedImage() {
        let html = "<a href=\"https://example.com/\"><img src=\"https://example.com/favicon.ico\" alt=\"alt text\" /></a>"
        let result = shouldMakeAttributedString(fromHTML: html)
        XCTAssertNotNil(result.attribute(NSLinkAttributeName, at: 0, effectiveRange: nil), "should have link attribute in: \(result)")

        let string = result.string
        XCTAssertTrue(string.hasPrefix("["), "should start with [: \(string)")
        XCTAssertTrue(string.hasSuffix("]"), "should end with ]: \(string)")
        XCTAssertTrue(string.contains("alt text"), "should have alt text inside: \(string)")
    }


    // MARK: - Renders block content
    func testOrderedList() {
        let html = "<ol><li>1</li><li>2</li></ol>"
        let expected = TenCenturiesHTMLParser.paragraphSeparator + "\t1. 1" + TenCenturiesHTMLParser.paragraphSeparator + "\t2. 2"
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), NSAttributedString(string: expected, attributes: TenCenturiesHTMLParser.list(atIndentLevel: 1)))
    }

    func testUnorderedList() {
        let html = "<ul><li>A</li><li>B</li></ul>"
        let expected = TenCenturiesHTMLParser.paragraphSeparator + "\t• A" + TenCenturiesHTMLParser.paragraphSeparator + "\t• B"
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), NSAttributedString(string: expected, attributes: TenCenturiesHTMLParser.list(atIndentLevel: 1)))
    }

    func SKIPPED_testNestedLists() {
        // AFAICT, Blurbs don't support nested lists. Now I'm curious about 10C blogpost Markdown…
        // Confirmed by @matigo not to support nested lists: https://10centuries.org/post/106230
    }

    func testListItemWithFootnoteClassSuperscriptsIndexAndOmitsDot() {
        let html = "<ol><li class=\"footnote\">footnote text</li></ol>"
        let result = shouldMakeAttributedString(fromHTML: html)

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
        let expected = TenCenturiesHTMLParser.paragraphSeparator + "\t• Single indent."
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), NSAttributedString(string: expected, attributes: TenCenturiesHTMLParser.list(atIndentLevel: 1)))
    }

    func testPreFormattedText() {
        let html = "<pre>this is    preformatted text</pre>"
        let expected = "this is    preformatted text"
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), NSAttributedString(string: expected, attributes: TenCenturiesHTMLParser.paragraph))
    }

    func testBlockquote() {
        let html = "<blockquote>quoted</blockquote>"
        let rendered = shouldMakeAttributedString(fromHTML: html)
        XCTAssertEqual(rendered.string, "quoted")

        guard let style = rendered.attribute(NSParagraphStyleAttributeName, at: 0, effectiveRange: nil) as? NSParagraphStyle else {
            return XCTFail("expected to find paragraph style at index 0 in: \(rendered)")
        }

        XCTAssertGreaterThan(style.firstLineHeadIndent, 0, "expected strictly positive first-line head-indent")
        XCTAssertGreaterThan(style.headIndent, 0, "expected strictly positive head-indent")
    }

    func testParagraphInBlockquoteIsStillIndented() {
        // See post: 114047
        let quoted = "This is a block quote."
        let html = "<blockquote>  <p>\(quoted)</p></blockquote>"
        let rendered = shouldMakeAttributedString(fromHTML: html)
        let range = (rendered.string as NSString).range(of: quoted)
        guard range.location != NSNotFound else {
            return XCTFail("failed to quoted string “\(quoted)” in: \(rendered)")
        }

        guard let style = rendered.attribute(NSParagraphStyleAttributeName, at: range.location, effectiveRange: nil) as? NSParagraphStyle else {
            return XCTFail("expected to find paragraph style in range \(range) of: \(rendered)")
        }

        XCTAssertGreaterThan(style.firstLineHeadIndent, 0, "expected strictly positive first-line head-indent")
        XCTAssertGreaterThan(style.headIndent, 0, "expected strictly positive head-indent")
    }


    // MARK: - Renders decorations
    func testHorizontalRule() {
        let html = "<hr />"
        let expected = TenCenturiesHTMLParser.paragraphSeparator
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), NSAttributedString(string: expected, attributes: TenCenturiesHTMLParser.paragraph))
    }

    func testImageFormatsAsBracketedImageColonAndAltTextInItalicsWithURLInAttributes() {
        // Uses the NSAttachmentCharacter U+FFFC aka the replacement character (question mark in a diamond, often) as the text, and then injects the image using the attributes.
        // See: https://developer.apple.com/reference/uikit/nstextattachment#
        // But for now, I think I'll just show the ALT text. We'll have to sort out how to update these as the images arrive…
        let html = "<img src=\"//example.com\" alt=\"an image\" />"

        let expectedHTML = "<em>[Image: an image]</em>"
        let renderedString = shouldMakeAttributedString(fromHTML: expectedHTML).mutableCopy() as! NSMutableAttributedString
        renderedString.addAttributes(
            [TenCenturiesHTMLParser.imageSourceURLAttributeName: URL(string: "https://example.com")!],
            range: NSRange(location: 0, length: renderedString.length))
        XCTAssertEqual(shouldMakeAttributedString(fromHTML: html), renderedString)
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
