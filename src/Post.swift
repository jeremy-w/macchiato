import Foundation

struct Post {
    let id: String
    let account: Account
    var content: String
    let html: String

    let privacy: String
    let thread: (root: String, replyTo: String)?
    let parentID: String?
    /// Not provided in Global, but is provided in threads.
    let client: String?

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

    let geo: Geo?
    let title: String

    static func makeFake() -> Post {
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
            parent: nil,
            geo: nil,
            title: "")
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
            parent: nil,
            geo: nil,
            title: "")
    }
}


extension Post {
    var author: String {
        return account.username
    }
}


// MARK: - Assists in updates
extension Post {
    /// Returns `self` with `originalPost` AKA `parent` set to the new value.
    ///
    /// Used when applying star actions to reposts.
    func withUpdatedOriginalPost(_ originalPost: Post?) -> Post {
        let withUpdatedOriginalPost = Post(
            id: id,
            account: account,
            content: content,
            html: html,
            privacy: privacy,
            thread: thread,
            parentID: parentID,
            client: client,
            mentions: mentions,
            created: created,
            updated: updated,
            published: published,
            deleted: deleted,
            you: you,
            stars: stars,
            parent: originalPost,
            geo: geo,
            title: title)
        return withUpdatedOriginalPost
    }

    /// Returns `nil` if no update needed, otherwise `self` updated to reflect the new `Post`.
    func updated(forChangedPost changedPost: Post) -> Post? {
        if id == changedPost.id {
            return changedPost
        }

        if let original = originalPost, original.id == changedPost.id {
            return self.withUpdatedOriginalPost(changedPost)
        }

        return nil
    }
}


extension Post {
    func replyTemplate(notMentioning handles: [String]) -> String {
        let isReplyToOwnPost = account.isYou
        guard !isReplyToOwnPost else {
            // Carry over current mentions, or supply an empty body.
            let sorted = orderedMentions
            guard let main = sorted.first?.current else {
                return ""
            }

            let bystanders = sorted.dropFirst().map({ $0.current })
            return Post.replyTemplate(main: main, bystanders: bystanders)
        }

        let main = account.username
        let bystanders = mentions.compactMap { $0.isYou ? nil : $0.current }
        return Post.replyTemplate(main: main, bystanders: bystanders)
    }

    /// Invoke like `replyTemplate(main: "matigo", bystanders: ["streakmachine", "gtwilson"])`
    ///
    /// Bystanders can be empty.
    private static func replyTemplate(main: String, bystanders: [String]) -> String {
        guard !bystanders.isEmpty else {
            return "@\(main) "
        }

        return "@\(main) \n\n/@" + bystanders.joined(separator: " @")
    }

    /// Returns `mentions` sorted in the order they are mentioned in `content`.
    var orderedMentions: [Mention] {
        let decorated = mentions.map({ (mention: Mention) -> (String.Index?, Mention) in
            let name = "@" + mention.name
            let range = content.range(of: name)
            return (range?.lowerBound, mention)
        })

        let sorted = decorated.sorted(by: { (left, right) -> Bool in
            switch (left.0, right.0) {
            case let (posleft?, posright?):
                return posleft < posright

            case (_?, nil):
                return true

            case (nil, _?):
                return false

            case (nil, nil):
                return false
            }
        })

        let orderedMentions = sorted.map({ $0.1 })
        return orderedMentions
    }
}


extension Post {
    struct You {
        var authored: Bool = false
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
        /// The account name at the time of the mention. `.as`
        let name: String

        /// The account GUID.
        let id: String

        /// The current account name - often the same as "name".
        let current: String

        let isYou: Bool
    }

    enum PinColor {
        case black
        case blue
        case green
        case orange
        case red
        case yellow
    }

    enum Flavor: String, Equatable, CaseIterable {
        case article = "post.article"
        case bookmark = "post.bookmark"
        case note = "post.note"
        case quote = "post.quotation"

        // The rest I've seen Nice ask for with Global,
        // but they aren't doc'd.
        case blog = "post.blog"
        case photo = "post.photo"
        case todo = "post.todo"
    }

    struct Geo: Equatable {
        let name: String
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
    }
}


extension Post.Mention: Equatable {
    static func == (my: Post.Mention, your: Post.Mention) -> Bool {
        return my.id == your.id
            && my.current == your.current
            && my.name == your.name
    }
}
