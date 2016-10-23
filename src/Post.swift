import Foundation

struct Post {
    let id: String
    let author: String
    let date: Date
    var content: String

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
        return Post(
            id: UUID().uuidString,
            author: pick(["@someone", "@someone_else", "@not_you"]),
            date: now,
            content: Array(repeating: "This is some awesome text.", count: randomNumber(in: 1 ..< 50)).joined(separator: " "),
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
    var replyTemplate: String {
        let target = author
        // (@jeremy-w/2016-10-23)FIXME: We need the post.account.id to properly do this comparison.
        let bystanders = mentions.filter { $0.current != target }.map { $0.current }
        guard !bystanders.isEmpty else {
            return "@\(author) "
        }

        return "@\(author) \n\n// " + bystanders.joined(separator: " ")
    }
}


struct EditingPost {
    var content: String

    let channel = 1
    let updating: String?
    let replyTo: String?
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
