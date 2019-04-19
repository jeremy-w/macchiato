import UIKit
import Kingfisher

/**
 Converts the HTML fragment into an attributed string.

 Images will be displayed using their alt-text.
 Their corresponding URLs will be set as the value of `TenCenturiesHTMLParser.imageSourceURLAttributeName` attributes.
 */
func makeAttributedString(fromHTML html: String) -> NSAttributedString? {
    // (jeremy-w/2017-02-16)FIXME: This should return optional, and then we can fall back to raw Markdown.
    let fixedUp = html
        .replacingOccurrences(of: "<hr>", with: "<hr />")
        .replacingOccurrences(of: "<br>", with: "<br />")
        .replacingOccurrences(of: "\u{0010}", with: "\n")
    let withRootNode = "<body>" + fixedUp + "</body>"
    guard let utf8 = withRootNode.data(using: .utf8) else {
        print("HTML: ERROR: Failed to convert string to UTF-8–encoded data: returning as-is")
        return NSAttributedString(string: html)
    }

    let parser = TenCenturiesHTMLParser(data: utf8, from: withRootNode)
    do {
        return try parser.parse().unwrap()
    } catch {
        print("HTML: ERROR: Failed to parse string with error:", error, "- string:", withRootNode)
        return nil
    }
}

public extension NSAttributedString.Key {
    /// All image elements with valid `src` URL will have this attribute set on the alt-text range in the text returned by `parse()`.
    /// Its value is a `URL`.
    static let macchiatoImageSourceURL = NSAttributedString.Key("com.jeremywsherman.Macchiato.ImageSourceURL")

    /// Mentions like `@name` have this applied. The value is a numeric `String`.
    static let macchiatoAccountID = NSAttributedString.Key("com.jeremywsherman.Macchiato.mention.AccountID")

    /// Text like `#tag` has this applied. The value is a `String` like `"tag"` (i.e., omitting the hashmark).
    static let macchiatoHashtag = NSAttributedString.Key("com.jeremywsherman.Macchiato.Hashtag")

    /// Text like `> quote` has this applied. The value is a strictly positive `Int`.
    /// In future, we might have a custom renderer stick a vertical bar to its left.
    static let macchiatoBlockquoteLevel = NSAttributedString.Key("com.jeremywsherman.Macchiato.blockquoteLevel")
}

final class TenCenturiesHTMLParser: NSObject, XMLParserDelegate {
    public init(data: Data, from source: String) {
        self.data = data
        self.source = source
    }

    private let data: Data
    private let source: String

    public func parse() -> Result<NSAttributedString> {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            print("ERROR: XML parsing failed at line=\(parser.lineNumber) column=\(parser.columnNumber). Partial result=\(result) attributesStack=\(attributesStack) atStartOfListItem=\(atStartOfListItem)")
            let error = parser.parserError ?? TenCenturiesError.other(
                message: "HTML parsing failed without any parserError",
                info: ["data": data, "source": source])
            return .failure(error)
        }
        return .success(result)
    }

    private var result = NSMutableAttributedString()

    typealias Attributes = [NSAttributedString.Key: Any]
    private var attributesStack = [Attributes]()

    /// The attributes stack is not popped at the end of one of these elements.
    private let elementsWithoutAttributes: Set = [
        "br",
        "hr",
        "li",
        "img",
        ]

    // MARK: - List State
    private struct HTMLList {
        let isOrdered: Bool
        let indentLevel: Int
        var itemCount: Int
    }
    private var listStack = [HTMLList]()
    private lazy var listItemIndexFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private var atStartOfListItem = false

    // swiftlint:disable:next cyclomatic_complexity
    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let styled = TenCenturiesHTMLParser.self
        switch element {
        case "body":
            attributesStack.append(TenCenturiesHTMLParser.applyParagraph(to: currentAttributes))

        case "p", "pre":
            attributesStack.append(TenCenturiesHTMLParser.applyParagraph(to: currentAttributes))
            if result.length > 0 && !atStartOfListItem {
                result.append(TenCenturiesHTMLParser.attributedParagraphSeparator)
                if element == "p" {
                    // Block paragraph style - full blank line serves as separator.
                    result.append(TenCenturiesHTMLParser.attributedParagraphSeparator)
                }
            }
            atStartOfListItem = false

        case "blockquote":
            attributesStack.append(TenCenturiesHTMLParser.applyBlockquote(to: currentAttributes))

        case "hr":
            result.append(TenCenturiesHTMLParser.attributedParagraphSeparator)

        case "em":
            attributesStack.append(TenCenturiesHTMLParser.applyItalicAttributes(to: currentAttributes))

        case "strong":
            attributesStack.append(TenCenturiesHTMLParser.applyBoldAttributes(to: currentAttributes))

        case "code":
            attributesStack.append(TenCenturiesHTMLParser.applyCodeAttributes(to: currentAttributes))

        case "sup":
            attributesStack.append(TenCenturiesHTMLParser.applySuperscriptAttributes(to: currentAttributes))

        case "strike":
            attributesStack.append(TenCenturiesHTMLParser.applyStrikethroughAttributes(to: currentAttributes))

        case "a":
            attributesStack.append(
                TenCenturiesHTMLParser.applyAnchorAttributes(
                    href: attributes["href"],
                    title: attributes["title"],
                    to: currentAttributes))

        case "span":
            if let classAttribute = attributes["class"] {
                switch classAttribute {
                case "account":
                    let accountID = attributes["data-account-id"] ?? ""
                    attributesStack.append(TenCenturiesHTMLParser.applyMentionAttributes(forAccountID: accountID, to: currentAttributes))

                case "hash":
                    let hashtag = attributes["data-hash"] ?? ""
                    attributesStack.append(TenCenturiesHTMLParser.applyAttributes(forHashtag: hashtag, to: currentAttributes))

                default:
                    print("HTML: WARNING: Unknown <span> class encountered:", classAttribute, "- all attributes:", attributes)
                    // Append some attributes so we don't throw off our stack.
                    attributesStack.append(styled.paragraph)
                }
            }

        case "br":
            self.parser(parser, foundCharacters: lineSeparator)

        case "ol", "ul":
            let indentLevel = listStack.last.map({ $0.indentLevel + 1 }) ?? 1
            let webList = HTMLList(isOrdered: (element == "ol"), indentLevel: indentLevel, itemCount: 0)
            listStack.append(webList)
            attributesStack.append(TenCenturiesHTMLParser.list(atIndentLevel: indentLevel))

        case "li":
            guard var webList = listStack.popLast() else { break }
            webList.itemCount += 1
            listStack.append(webList)

            let separator = TenCenturiesHTMLParser.paragraphSeparator

            let attributesForIndentation = styled.list(atIndentLevel: webList.indentLevel)
            let listItem = NSMutableAttributedString(string: separator, attributes: attributesForIndentation)

            let itemLabel: NSAttributedString
            if webList.isOrdered {
                let number = listItemIndexFormatter.string(from: NSNumber(value: webList.itemCount)) ?? String(describing: webList.itemCount)
                let isFootnote = (attributes["class"] ?? "") == "footnote"
                itemLabel = isFootnote
                    ? NSAttributedString(string: number, attributes: TenCenturiesHTMLParser.applySuperscriptAttributes(to: currentAttributes))
                    : NSAttributedString(string: number + ". ", attributes: attributesForIndentation)
            } else {
                itemLabel = NSAttributedString(string: "• ", attributes: attributesForIndentation)
            }

            listItem.append(itemLabel)
            result.append(listItem)
            atStartOfListItem = true

        case "img":
            let altText = attributes["alt"] ?? NSLocalizedString("«no alt text given»", comment: "image text")
            let format = NSLocalizedString("[Image: %@]", comment: "%@ is the alt attribute text from the img tag")
            var stringAttributes = TenCenturiesHTMLParser.applyItalicAttributes(to: currentAttributes)
            if let url = imageURL(from: attributes) {
                stringAttributes[.macchiatoImageSourceURL] = url
            } else {
                print("HTML: ERROR: Failed to build URL for image with attributes:", attributes)
            }
            result.append(
                NSAttributedString(
                    string: String.localizedStringWithFormat(format, altText),
                    attributes: stringAttributes))

        default:
            print("HTML: WARNING: Unknown element:", element, "- attributes:", attributes, "; treating as <P> tag")
            attributesStack.append(styled.paragraph)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        result.append(NSAttributedString(string: string, attributes: currentAttributes))
    }

    var currentAttributes: Attributes {
        return attributesStack.last ?? [:]
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        atStartOfListItem = false
        if element == "ol" || element == "ul", let webList = listStack.popLast() {
            if webList.isOrdered != (element == "ol") {
                print("HTML: WARNING: OL/UL mismatch: Saw close tag for", element, "but top of list stack was the other flavor!")
            }
        }

        guard !elementsWithoutAttributes.contains(element) else {
            return
        }

        guard let _ = attributesStack.popLast() else {
            print("HTML: ERROR: Stack underflow on popping element:", element, "- source text:", source)
            return
        }
    }

    func imageURL(from attributes: [String: String]) -> URL? {
        guard let imageSource = attributes["src"] else {
            return nil
        }

        let maybeURL: URL?
        if let urlPossiblyLackingScheme = URL(string: imageSource) {
            if urlPossiblyLackingScheme.scheme == nil {
                maybeURL = URL(string: "https:" + imageSource)
            } else {
                maybeURL = urlPossiblyLackingScheme
            }
        } else {
            maybeURL = nil
        }
        return maybeURL
    }

    /**
     Returns a text attachment whose `image` will eventually be set to the image at `url`.

     - NOTE: Assigning to the `image` does not trigger relayout of an attributed string containing this attachment.
       The attachment will also be the full size of the image, which might not fit in the rendered container.
       We might fix this in future by using a custom text attachment subclass aware of its rendering context
       and of the un/loaded state of its image.
     */
    func textAttachment(for url: URL) -> NSTextAttachment {
        let attachment = NSTextAttachment()
        KingfisherManager.shared.retrieveImage(with: url) { (result: Kingfisher.Result<RetrieveImageResult, KingfisherError>) in
            do {
                let image = try result.get().image
                print("HTML: DEBUG: Fetched image for", url as Any, ": image", image)
                attachment.image = image
                // (jeremy-w/2017-02-03)FIXME: This appears not to actually trigger a re-render. :(
                // So you have to scroll away and back to get it in cache to see it.
                // And then it winds up too wide anyway. Maybe needs a custom text attachment subclass
                // to get proper sizing.
            } catch {
                print("HTML: ERROR: Failed to fetch image for", url as Any, ": error", error as Any)
            }
        }
        return attachment
    }


    // MARK: - Rich Text Attributes
    static func applyParagraph(to attributes: Attributes) -> Attributes {
        var paragraphy = attributes

        let style = (paragraphy[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default
        let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle  // swiftlint:disable:this force_cast
        mutableStyle.lineBreakMode = .byWordWrapping
        paragraphy[.paragraphStyle] = mutableStyle

        guard paragraphy[.font] == nil else {
            return paragraphy
        }

        paragraphy[.font] = UIFont.preferredFont(forTextStyle: .body)
        return paragraphy
    }
    static var paragraph: Attributes {
        return TenCenturiesHTMLParser.applyParagraph(to: [:])
    }

    static var attributedParagraphSeparator = NSAttributedString(
        string: TenCenturiesHTMLParser.paragraphSeparator,
        attributes: TenCenturiesHTMLParser.paragraph)
    static var paragraphSeparator = "\r\n"
    //swiftlint:disable line_length
    /// Line separator: See: [SO: What is the line separator character used for?](https://stackoverflow.com/questions/3072152/what-is-unicode-character-2028-ls-line-separator-used-for)
    /// See: [Unicode Newline Guidelines](http://www.unicode.org/standard/reports/tr13/tr13-5.html)
    /// And the Cocoa take: [String Programming Guide: Words, Paragraphs, and Line Breaks](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Strings/Articles/stringsParagraphBreaks.html#//apple_ref/doc/uid/TP40005016-SW1)
    var lineSeparator = "\u{2028}"
    //swiftlint:enable line_length

    static func applyItalicAttributes(to attributes: Attributes) -> Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let current = attributes[NSAttributedString.Key.font] as? UIFont
        let pointSize = (current ?? UIFont.preferredFont(forTextStyle: .body)).pointSize
        let font = toggle(.traitItalic, of: current) ?? UIFont.italicSystemFont(ofSize: pointSize)
        var italicized = attributes
        italicized[.font] = font
        return italicized
    }

    static func toggle(_ trait: UIFontDescriptor.SymbolicTraits, of font: UIFont?) -> UIFont? {
        guard let current = font else {
            return nil
        }

        let traitsWithTraitToggled = current.fontDescriptor.symbolicTraits.symmetricDifference(trait)
        guard let descriptor = current.fontDescriptor.withSymbolicTraits(traitsWithTraitToggled) else {
            print("HTML: ERROR: Failed to build font descriptor with trait", trait, "toggled in descriptor:", current.fontDescriptor)
            return nil
        }

        return UIFont(descriptor: descriptor, size: current.pointSize)
    }

    static func applyBoldAttributes(to attributes: Attributes) -> Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let current = attributes[NSAttributedString.Key.font] as? UIFont
        let pointSize = (current ?? UIFont.preferredFont(forTextStyle: .body)).pointSize
        let font = toggle(.traitBold, of: current) ?? UIFont.boldSystemFont(ofSize: pointSize)
        var bolded = attributes
        bolded[.font] = font
        return bolded
    }

    static func applyCodeAttributes(to attributes: Attributes) -> Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let current = (attributes[NSAttributedString.Key.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        let font = makeMonospaceByHookOrByCrook(current)
        var codified = attributes
        codified[.font] = font
        codified[.backgroundColor] = #colorLiteral(red: 0.9764705882, green: 0.9490196078, blue: 0.9568627451, alpha: 1)
        codified[.foregroundColor] = #colorLiteral(red: 0.7803921569, green: 0.1450980392, blue: 0.1490196078, alpha: 1)
        return codified
    }

    static func makeMonospaceByHookOrByCrook(_ current: UIFont) -> UIFont {
        let descriptor = current.fontDescriptor
        if let monospaceDescriptor = descriptor.withSymbolicTraits(.traitMonoSpace) {
            let font = UIFont(descriptor: monospaceDescriptor, size: monospaceDescriptor.pointSize)
            return font
        }

        // Noticed in testing that, whenever I saw: NSCTFontUIUsageAttribute: UICTFontTextStyleBody,
        // it'd spit back .SFUIText as the font no matter what, even when I set an explicit name.
        //
        // So, I tried canceling it out, but that only fixed the case of regular text,
        // because the descriptor for bold (.SFUIText-Semibold font name) relied on
        // NSCTFontUIUsageAttribute = UICTFontTextStyleEmphasizedBody.
        //
        // I leave this attempt here against my trying to be clever in future.
        let menloDescriptor = descriptor.withFamily("Menlo")//.addingAttributes(["NSCTFontUIUsageAttribute": NSNull()])
        let font = UIFont(descriptor: menloDescriptor, size: menloDescriptor.pointSize)
        if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
            return font
        }

        let isBold = descriptor.symbolicTraits.contains(.traitBold)
        let isItalic = descriptor.symbolicTraits.contains(.traitItalic)
        let name: String
        switch (isBold, isItalic) {
        case (true, true):
            name = "Menlo-BoldItalic"

        case (true, false):
            name = "Menlo-Bold"

        case (false, true):
            name = "Menlo-Italic"

        case (false, false):
            name = "Menlo-Regular"
        }
        guard let menlo = UIFont(name: name, size: descriptor.pointSize) else {
            print("HTML: ERROR: Failed to get font named", name, "of size", descriptor.pointSize, "- falling back to:", current.fontDescriptor)
            return current
        }
        return menlo
    }

    static func applySuperscriptAttributes(to attributes: Attributes) -> Attributes {
        var superscripted = attributes
        #if os(macOS)
            if #available(macOS 10.10, *) {
                superscripted[NSSuperscriptAttributeName] = 1.0
            }
        #else
        let current = (attributes[NSAttributedString.Key.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let descriptor = current.fontDescriptor
            let font = UIFont(descriptor: descriptor, size: descriptor.pointSize / 2)
            superscripted[.font] = font
            superscripted[.baselineOffset] = descriptor.pointSize / 3
        #endif
        return superscripted
    }

    static func applyStrikethroughAttributes(to attributes: Attributes) -> Attributes {
        var strikethroughAttributes = attributes
        strikethroughAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        return strikethroughAttributes
    }

    static func applyAnchorAttributes(href: String?, title: String?, to attributes: Attributes) -> Attributes {
        // (jeremy-w/2017-01-22)TODO: This might need to also add underline or similar visual shift.
        // (jeremy-w/2017-01-22)XXX: Note we're ignoring the title - no idea what to do with that. :\
        var anchorAttributes = attributes
        anchorAttributes[.link] = href ?? "about:blank"
        return anchorAttributes
    }

    static func applyMentionAttributes(forAccountID accountID: String, to attributes: Attributes) -> Attributes {
        var mentionAttributes = applyBoldAttributes(to: attributes)
        mentionAttributes[.macchiatoAccountID] = accountID
        return mentionAttributes
    }

    static func applyAttributes(forHashtag hashtag: String, to attributes: Attributes) -> Attributes {
        var hashtagAttributes = applyItalicAttributes(to: attributes)
        hashtagAttributes[.macchiatoHashtag] = hashtag
        return hashtagAttributes
    }

    static func list(atIndentLevel indentLevel: Int) -> Attributes {
        var attributes = applyParagraph(to: [.font: UIFont.preferredFont(forTextStyle: .body)])

        let style = (attributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default
        let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle  // swiftlint:disable:this force_cast

        // 28 is the default tab stop, which mirrors our old "stick some tabs on" approach, which looked OK.
        let indentation = CGFloat(indentLevel) * 28.0
        mutableStyle.firstLineHeadIndent = indentation
        // (jeremy-w/2017-03-25)TODO: Would be nice to do a proper hanging-indent, but then need to measure the item label.
        mutableStyle.headIndent = indentation + 8.0

        attributes[.paragraphStyle] = mutableStyle
        return attributes
    }

    static func applyBlockquote(to attributes: Attributes) -> Attributes {
        var quoted = attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.setParagraphStyle(quoted[.paragraphStyle] as? NSParagraphStyle ?? NSParagraphStyle.default)
        paragraphStyle.firstLineHeadIndent += 12
        paragraphStyle.headIndent += 12
        quoted[.paragraphStyle] = paragraphStyle
        quoted[.font] = UIFont.preferredFont(forTextStyle: .callout)
        quoted[.foregroundColor] = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        quoted[.macchiatoBlockquoteLevel] = (quoted[.macchiatoBlockquoteLevel] as? Int ?? 0) + 1
        return quoted
    }
}
