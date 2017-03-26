import Foundation

struct Post {
    let id: String
    let account: Account
    var content: String
    let html: String

    let privacy: String
    let thread: (root: String, replyTo: String)?
    let parentID: String?
    let client: String

    let mentions: [Mention]

    let created: Date
    /// If the same as `date`, then the post has not been edited.
    var updated: Date
    var published: Date
    var deleted: Bool

    var you: You

    /* STATS */
    var stars: [Star]
    struct Star {
        let avatarURL: URL
        let userID: String
        let userAtName: String
        let starredAt: Date
        /*
         {
         "avatar_url" = "//cdn.10centuries.org/Wf649r/45ab260697817fad00290ff93980ec4b.jpeg";
         id = 27;
         name = "@jws";
         "starred_at" = "2017-02-18 07:05:15";
         "starred_unix" = 1487401515;
         }
         */
    }
    let parent: Any?  // actually a Post, if present
    var originalPost: Post? {
        return parent as? Post
    }

    static func makeFake() -> Post {
        // swiftlint:disable:previous function_body_length
        let now = Date()
        let text = Array(repeating: "This is some awesome text.", count: randomNumber(in: 1 ..< 50)).joined(separator: " ")
        return Post(
            id: UUID().uuidString,
            account: Account.makeFake(),
            content: text,
            html: "<p>" + text + "</p>",
            privacy: "visibility.public",
            thread: nil,
            parentID: nil,
            client: "Magicat",
            mentions: [],
            created: now,
            updated: now,
            published: now,
            deleted: false,
            you: You(),
            stars: [],
            parent: nil)
    }

    static func displayingRawJSON(_ json: Any, errorMessage message: String) -> Post {
        let body = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted))
            .flatMap({ String(data: $0, encoding: .utf8) })
            ?? String(reflecting: json)

        let now = Date()

        let headerFormat = NSLocalizedString("Post parsing failed: %@", comment: "%@ is error message")
        let header = String.localizedStringWithFormat(headerFormat, message)

        return Post(
            id: "—",
            account: Account.makeFake(),
            content: "**" + header + "**\n\n```\n" + body + "```\n",
            html: "<p><strong>" + header + "</strong></p><pre><code>" + body + "</pre></code>",
            privacy: "visibility.public",
            thread: nil,
            parentID: nil,
            client: "—",
            mentions: [],
            created: now,
            updated: now,
            published: now,
            deleted: false,
            you: You(),
            stars: [],
            parent: nil)
    }
}


extension Post {
    var author: String {
        return account.username
    }
}


// MARK: - Assists in updates
extension Post {
    func needsUpdate(forChangedPostID changedPostID: PostID) -> Bool {
        let isPostItself = id == changedPostID
        let isRepost = originalPost.map({ $0.id == changedPostID }) ?? false
        let needsUpdate = isPostItself || isRepost
        return needsUpdate
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
