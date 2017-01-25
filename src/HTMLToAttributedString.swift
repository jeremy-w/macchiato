import UIKit

func makeAttributedString(fromHTML html: String) -> NSAttributedString {
    let fixed = "<body>" + html.replacingOccurrences(of: "<hr>", with: "<hr />") + "</body>"
    guard let utf8 = fixed.data(using: .utf8) else {
        print("HTML: ERROR: Failed to convert string to UTF-8–encoded data: returning as-is")
        return NSAttributedString(string: html)
    }

    let parser = Parser(data: utf8, from: fixed)
    do {
        return try parser.parse().unwrap()
    } catch {
        print("HTML: ERROR: Failed to parse string with error:", error, "- string:", fixed)
        return NSAttributedString(string: html)
    }
}


final class Parser: NSObject, XMLParserDelegate {
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
            let error = parser.parserError ?? TenCenturiesError.other(message: "HTML parsing failed without any parserError", info: ["data": data, "source": source])
            return .failure(error)
        }
        return .success(result)
    }

    var attributesStack = [[String: Any]]()

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

    // swiftlint:disable:next cyclomatic_complexity
    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch element {
        case "body":
            attributesStack.append(paragraphAttributes)

        case "p", "pre":
            attributesStack.append(paragraphAttributes)
            if result.length > 0 {
                result.append(Parser.attributedParagraphSeparator)
            }

        case "hr":
            attributesStack.append(paragraphAttributes)
            if result.length > 0 {
                result.append(Parser.attributedParagraphSeparator)
            }
            self.parser(parser, foundCharacters: "⁂")

        case "em":
            attributesStack.append(Parser.italicAttributes)

        case "strong":
            attributesStack.append(Parser.boldAttributes)

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
                    attributesStack.append(Parser.mentionAttributes(forAccountID: accountID))

                case "hash":
                    let hashTag = attributes["data-hash"] ?? ""
                    attributesStack.append(Parser.attributes(forHashTag: hashTag))

                default:
                    print("HTML: WARNING: Unknown <span> class encountered:", classAttribute, "- all attributes:", attributes)
                    // Append some attributes so we don't throw off our stack.
                    attributesStack.append(paragraphAttributes)
                }
            }

        case "br":
            self.parser(parser, foundCharacters: lineSeparator)

        case "ol", "ul":
            let indentLevel = listStack.last.map({ $0.indentLevel + 1 }) ?? 1
            let webList = HTMLList(isOrdered: (element == "ol"), indentLevel: indentLevel, itemCount: 0)
            listStack.append(webList)
            attributesStack.append(Parser.attributes(forListAtIndentLevel: indentLevel))

        case "li":
            guard var webList = listStack.popLast() else { break }
            webList.itemCount += 1
            listStack.append(webList)

            let separator = webList.itemCount > 1 ? Parser.paragraphSeparator : ""
            let indent = Array(repeating: "\t", count: webList.indentLevel).joined()

            let listItem = NSMutableAttributedString(string: separator + indent)
            if webList.isOrdered {
                let number = listItemIndexFormatter.string(from: NSNumber(value: webList.itemCount)) ?? String(describing: webList.itemCount)
                let isFootnote = (attributes["class"] ?? "") == "footnote"
                if isFootnote {
                    listItem.append(NSAttributedString(string: number, attributes: superscriptAttributes))
                } else {
                    listItem.append(NSAttributedString(string: number + ". "))
                }
            } else {
                listItem.append(NSAttributedString(string: "• "))
            }
            result.append(listItem)

        case "img":
            let altText = attributes["alt"] ?? NSLocalizedString("«no alt text given»", comment: "image text")
            let format = NSLocalizedString("[Image: %@]", comment: "%@ is alt text")
            result.append(NSAttributedString(string: String.localizedStringWithFormat(format, altText), attributes: Parser.italicAttributes))

        default:
            print("HTML: WARNING: Unknown element:", element, "- attributes:", attributes, "; treating as <P> tag")
            attributesStack.append(paragraphAttributes)
        }
    }

    let elementsWithoutAttributes: Set = [
        "br",
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

    var paragraphAttributes = [String: Any]()
    static var attributedParagraphSeparator = NSAttributedString(string: Parser.paragraphSeparator)
    static var paragraphSeparator = "\r\n"
    /// Line separator: See: [SO: What is the line separator character used for?](https://stackoverflow.com/questions/3072152/what-is-unicode-character-2028-ls-line-separator-used-for)
    /// See: [Unicode Newline Guidelines](http://www.unicode.org/standard/reports/tr13/tr13-5.html)
    /// And the Cocoa take: [String Programming Guide: Words, Paragraphs, and Line Breaks](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Strings/Articles/stringsParagraphBreaks.html#//apple_ref/doc/uid/TP40005016-SW1)
    var lineSeparator = "\u{2028}"

    static var italicAttributes: [String: Any] {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont.italicSystemFont(ofSize: descriptor.pointSize)
        return [NSFontAttributeName: font]
    }

    static var boldAttributes: [String: Any] {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont.boldSystemFont(ofSize: descriptor.pointSize)
        return [NSFontAttributeName: font]
    }

    var codeAttributes: [String: Any] {
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

    var superscriptAttributes: [String: Any] {
        #if os(macOS)
            if #available(macOS 10.10, *) {
                return [NSSuperscriptAttributeName: 1.0]
            }
        #endif

        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont(descriptor: descriptor, size: descriptor.pointSize / 2)
        return [NSFontAttributeName: font, NSBaselineOffsetAttributeName: descriptor.pointSize / 3]
    }

    var strikethroughAttributes: [String: Any] {
        return [NSStrikethroughStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue]
    }

    func anchorAttributes(href: String?, title: String?) -> [String: Any] {
        // (jeremy-w/2017-01-22)TODO: This might need to also add underline or similar visual shift.
        // (jeremy-w/2017-01-22)XXX: Note we're ignoring the title - no idea what to do with that. :\
        return [NSLinkAttributeName: href ?? "about:blank"]
    }

    static func mentionAttributes(forAccountID accountID: String) -> [String: Any] {
        var mentionAttributes = boldAttributes
        mentionAttributes["macchiato.mention.accountID"] = accountID
        return mentionAttributes
    }

    static func attributes(forHashTag hashTag: String) -> [String: Any] {
        var hashTagAttributes = italicAttributes
        hashTagAttributes["macchiato.hashTag"] = hashTag
        return hashTagAttributes
    }

    static func attributes(forListAtIndentLevel indentLevel: Int) -> [String: Any] {
        // Could muck with indents…
        var attributes = [String: Any]()
        return attributes
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
