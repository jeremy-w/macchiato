import UIKit

func makeAttributedString(fromHTML html: String) -> NSAttributedString {
    guard let utf8 = html.data(using: .utf8) else {
        print("HTML: ERROR: Failed to convert string to UTF-8–encoded data: returning as-is")
        return NSAttributedString(string: html)
    }

    let parser = Parser(data: utf8)
    do {
        return try parser.parse().unwrap()
    } catch {
        print("HTML: ERROR: Failed to parse string:", error)
        return NSAttributedString(string: html)
    }
}


private final class Parser: NSObject, XMLParserDelegate {
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

    var attributesStack = [[String: Any]]()
    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch element {
        case "p":
            attributesStack.append(paragraphAttributes)
            if result.length > 0 {
                result.append(paragraphSeparator)
            }

            case "em":
            attributesStack.append(italicAttributes)

        default:
            print("HTML: WARNING: Unknown element:", element, "- attributes:", attributes, "; treating as <P> tag")
            attributesStack.append(paragraphAttributes)
        }
    }

    var paragraphAttributes = [String: Any]()
    var paragraphSeparator = NSAttributedString(string: "\r\n")

    var italicAttributes: [String: Any] {
        // (jeremy-w/2017-01-22)XXX: We might need to sniff for "are we in a Title[1-3] header tag?" scenario
        // and use that instead of .body as the text style.
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        let font = UIFont.italicSystemFont(ofSize: descriptor.pointSize)
        return [NSFontAttributeName: font]
    }

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
        guard let _ = attributesStack.popLast() else {
            print("HTML: ERROR: Stack underflow on popping element:", element)
            return
        }
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
