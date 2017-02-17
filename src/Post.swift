import Foundation

struct Post {
    let id: String
    let account: Account
    let date: Date
    var content: String
    let html: String

    let privacy: String
    let thread: (root: String, replyTo: String)?
    let parentID: String?
    let client: String

    let mentions: [Mention]

    /// If the same as `date`, then the post has not been edited.
    var updated: Date
    var deleted: Bool

    var you: You

    static func makeFake() -> Post {
        // swiftlint:disable:previous function_body_length
        let now = Date()
        let text = Array(repeating: "This is some awesome text.", count: randomNumber(in: 1 ..< 50)).joined(separator: " ")
        return Post(
            id: UUID().uuidString,
            account: Account.makeFake(),
            date: now,
            content: text,
            html: "<p>" + text + "</p>",
            privacy: "visibility.public",
            thread: nil,
            parentID: nil,
            client: "Magicat",
            mentions: [],
            updated: now,
            deleted: false,
            you: You())
    }

    static func displayingRawJSON(_ json: Any, errorMessage message: String) -> Post {
        let body = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)).flatMap({ String(data: $0, encoding: .utf8) }) ?? String(reflecting: json)

        let now = Date()

        let headerFormat = NSLocalizedString("Post parsing failed: %@", comment: "%@ is error message")
        let header = String.localizedStringWithFormat(headerFormat, message)

        return Post(
            id: "—",
            account: Account.makeFake(),
            date: now,
            content: "**" + header + "**\n\n```\n" + body + "```\n",
            html: "<p><strong>" + header + "</strong></p><pre><code>" + body + "</pre></code>",
            privacy: "visibility.public",
            thread: nil,
            parentID: nil,
            client: "—",
            mentions: [],
            updated: now,
            deleted: false,
            you: You())
    }
}


extension Post {
    var author: String {
        return account.username
    }
}


extension Post {
    func replyTemplate(notMentioning handles: [String]) -> String {
        let target = account.id
        let omit = Set(handles)
        let bystanders = mentions
            .filter { $0.id != target && !omit.contains($0.current) }
            .map { $0.current }
        guard !bystanders.isEmpty else {
            return "@\(author) "
        }

        return "@\(author) \n\n// @" + bystanders.joined(separator: " @")
    }
}


extension Post {
    struct You {
        var wereMentioned: Bool = false
        var starred: Bool = false
        var pinned: PinColor?
        var reposted: Bool = false

        /// data.is_muted
        var muted: Bool = false

        /// data.is_visible
        var cannotSee: Bool = false
    }

    struct Mention {
        /// The account name at the time of the mention.
        let name: String

        /// The account ID.
        let id: String

        /// The current account name - often the same as "name".
        let current: String
    }

    enum PinColor {
        case black
        case blue
        case green
        case orange
        case red
        case yellow
    }
}


extension Post.Mention: Equatable {
    static func == (my: Post.Mention, your: Post.Mention) -> Bool {
        return my.id == your.id
            && my.current == your.current
            && my.name == your.name
    }
}
