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
        var muted: Bool = false
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
