import UIKit
import Kingfisher

func makeAttributedString(fromHTML html: String) -> NSAttributedString {
    let fixed = "<body>" + html.replacingOccurrences(of: "<hr>", with: "<hr />") + "</body>"
    guard let utf8 = fixed.data(using: .utf8) else {
        print("HTML: ERROR: Failed to convert string to UTF-8–encoded data: returning as-is")
        return NSAttributedString(string: html)
    }

    let parser = TenCenturiesHTMLParser(data: utf8, from: fixed)
    do {
        return try parser.parse().unwrap()
    } catch {
        print("HTML: ERROR: Failed to parse string with error:", error, "- string:", fixed)
        return NSAttributedString(string: html)
    }
}


final class TenCenturiesHTMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let source: String
    init(data: Data, from source: String) {
        self.data = data
        self.source = source
    }

    private var result = NSMutableAttributedString()
    func parse() -> Result<NSAttributedString> {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            let error = parser.parserError ?? TenCenturiesError.other(
                message: "HTML parsing failed without any parserError",
                info: ["data": data, "source": source])
            return .failure(error)
        }
        return .success(result)
    }

    typealias Attributes = [String: Any]
    var attributesStack = [Attributes]()

    struct HTMLList {
        let isOrdered: Bool
        let indentLevel: Int
        var itemCount: Int
    }
    var listStack = [HTMLList]()
    lazy var listItemIndexFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var atStartOfListItem = false

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
            attributesStack.append(styled.paragraph)

        case "p", "pre":
            attributesStack.append(styled.paragraph)
            if result.length > 0 && !atStartOfListItem {
                result.append(TenCenturiesHTMLParser.attributedParagraphSeparator)
            }
            atStartOfListItem = false

        case "hr":
            result.append(TenCenturiesHTMLParser.attributedParagraphSeparator)

        case "em":
            attributesStack.append(TenCenturiesHTMLParser.italicAttributes)

        case "strong":
            attributesStack.append(TenCenturiesHTMLParser.boldAttributes)

        case "code":
            attributesStack.append(codeAttributes)

        case "sup":
            attributesStack.append(superscriptAttributes)

        case "strike":
            attributesStack.append(strikethroughAttributes)

        case "a":
            attributesStack.append(anchorAttributes(href: attributes["href"], title: attributes["title"]))

        case "span":
            if let classAttribute = attributes["class"] {
                switch classAttribute {
                case "account":
                    let accountID = attributes["data-account-id"] ?? ""
                    attributesStack.append(TenCenturiesHTMLParser.mentionAttributes(forAccountID: accountID))

                case "hash":
                    let hashTag = attributes["data-hash"] ?? ""
                    attributesStack.append(TenCenturiesHTMLParser.attributes(forHashTag: hashTag))

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
            let indent = Array(repeating: "\t", count: webList.indentLevel).joined()

            let attributesForIndentation = styled.list(atIndentLevel: webList.indentLevel)
            let listItem = NSMutableAttributedString(string: separator + indent, attributes: attributesForIndentation)

            let itemLabel: NSAttributedString
            if webList.isOrdered {
                let number = listItemIndexFormatter.string(from: NSNumber(value: webList.itemCount)) ?? String(describing: webList.itemCount)
                let isFootnote = (attributes["class"] ?? "") == "footnote"
                itemLabel = isFootnote
                    ? NSAttributedString(string: number, attributes: superscriptAttributes)
                    : NSAttributedString(string: number + ". ", attributes: attributesForIndentation)
            } else {
                itemLabel = NSAttributedString(string: "• ", attributes: attributesForIndentation)
            }

            listItem.append(itemLabel)
            result.append(listItem)
            atStartOfListItem = true

        case "img":
            let altText = attributes["alt"] ?? NSLocalizedString("«no alt text given»", comment: "image text")
            let format = NSLocalizedString("[Image: %@]", comment: "%@ is alt text")
            var stringAttributes = TenCenturiesHTMLParser.italicAttributes
            if let url = imageURL(from: attributes) {
                stringAttributes[TenCenturiesHTMLParser.imageSourceURLAttributeName] = url
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

    /// The attributes stack is not popped at the end of one of these elements.
    let elementsWithoutAttributes: Set = [
        "br",
        "hr",
        "li",
        "img",
    ]

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let attributes = attributesStack.last
        if attributes == nil {
            print("HTML: ERROR: Found characters prior to any node:", string)
        }

        result.append(NSAttributedString(string: string, attributes: attributes ?? [:]))
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
        KingfisherManager.shared.retrieveImage(
            with: url,
            options: nil,
            progressBlock: nil,
            completionHandler: { (image, error, cacheType, url) in
                if let image = image {
                    print("HTML: DEBUG: Fetched image for", url as Any, ": image", image)
                    attachment.image = image
                    // (jeremy-w/2017-02-03)FIXME: This appears not to actually trigger a re-render. :(
                    // So you have to scroll away and back to get it in cache to see it.
                    // And then it winds up too wide anyway. Maybe needs a custom text attachment subclass
                    // to get proper sizing.
                } else {
                    print("HTML: ERROR: Failed to fetch image for", url as Any, ": error", error as Any)
                }
            })
        return attachment
    }


    // MARK: - Rich Text Attributes
    static let imageSourceURLAttributeName = "com.jeremywsherman.Macchiato.ImageSourceURL"
    static var paragraph: Attributes {
        return [NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body)]
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

    static var italicAttributes: Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont.italicSystemFont(ofSize: descriptor.pointSize)
        return [NSFontAttributeName: font]
    }

    static var boldAttributes: Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont.boldSystemFont(ofSize: descriptor.pointSize)
        return [NSFontAttributeName: font]
    }

    var codeAttributes: Attributes {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        guard let codeDescriptor = descriptor.withSymbolicTraits(.traitMonoSpace) else {
            print("HTML: ERROR: Unable to create font descriptor with symbolic trait MonoSpace based on descriptor:",
                  descriptor, "- defaulting to Menlo")
            let menlo = UIFontDescriptor(name: "Menlo-Regular", size: descriptor.pointSize)
            return [NSFontAttributeName: UIFont(descriptor: menlo, size: menlo.pointSize)]
        }

        let font = UIFont(descriptor: codeDescriptor, size: codeDescriptor.pointSize)
        return [NSFontAttributeName: font]
    }

    var superscriptAttributes: Attributes {
        #if os(macOS)
            if #available(macOS 10.10, *) {
                return [NSSuperscriptAttributeName: 1.0]
            }
        #endif

        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont(descriptor: descriptor, size: descriptor.pointSize / 2)
        return [NSFontAttributeName: font, NSBaselineOffsetAttributeName: descriptor.pointSize / 3]
    }

    var strikethroughAttributes: Attributes {
        return [NSStrikethroughStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue]
    }

    func anchorAttributes(href: String?, title: String?) -> Attributes {
        // (jeremy-w/2017-01-22)TODO: This might need to also add underline or similar visual shift.
        // (jeremy-w/2017-01-22)XXX: Note we're ignoring the title - no idea what to do with that. :\
        var attributes = TenCenturiesHTMLParser.paragraph
        attributes[NSLinkAttributeName] = href ?? "about:blank"
        return attributes
    }

    static func mentionAttributes(forAccountID accountID: String) -> Attributes {
        var mentionAttributes = boldAttributes
        mentionAttributes["macchiato.mention.accountID"] = accountID
        return mentionAttributes
    }

    static func attributes(forHashTag hashTag: String) -> Attributes {
        var hashTagAttributes = italicAttributes
        hashTagAttributes["macchiato.hashTag"] = hashTag
        return hashTagAttributes
    }

    static func list(atIndentLevel indentLevel: Int) -> Attributes {
        // Could muck with indents…
        return [NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body)]
    }
}


private final class TreeParser: NSObject, XMLParserDelegate {
    private let data: Data
    init(data: Data) {
        self.data = data
    }

    private var result = NSMutableAttributedString()
    func parse() -> Result<NSAttributedString> {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            let error = parser.parserError ?? TenCenturiesError.other(message: "HTML parsing failed without any parserError", info: data)
            return .failure(error)
        }
        return .success(result)
    }

    private final class Node {
        let name: String
        let attributes: [String: String]
        var children = [Node]()

        init(name: String, attributes: [String: String], children: [Node] = []) {
            self.name = name
            self.attributes = attributes
            self.children = children
        }
    }

    private var stack = [Node]()
    func parserDidStartDocument(_ parser: XMLParser) {
        stack.append(Node(name: "root", attributes: [:]))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        stack.append(Node(name: element, attributes: attributes))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let top = stack.last else {
            print("HTML: ERROR: Found characters prior to any node:", string)
            return
        }

        top.children.append(Node(name: "text", attributes: ["text": string]))
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard let child = stack.popLast(), let parent = stack.last else {
            print("HTML: ERROR: Expected finished child to always have a parent: stack", stack)
            return
        }

        parent.children.append(child)
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Hmm, why did I build that tree, again?
    }
}
