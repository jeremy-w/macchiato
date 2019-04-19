import Foundation

struct Account {
    let id: String
    let username: String

    /// Like: `(first: "Jeremy W.", last: "Sherman", display: "jws")`
    let name: (first: String, last: String, display: String)

    /**
     Always present, thanks to the 10C default URL.
     */
    let avatarURL: URL
    static let defaultAvatarURL = URL(string: "https://cdn.10centuries.org/avatars/default.png")!

    let verified: URL?
    let descriptionMarkdown: String
    let descriptionHTML: String
    let timezone: String

    enum CountKey {
        static let blogposts = "blogposts"
        static let followers = "followers"
        static let following = "following"
        static let podcasts = "podcasts"
        static let socialposts = "socialposts"
        static let stars = "stars"
    }
    let counts: [String: Int]  // following, followers, stars, posts of various sizes
    let createdAt: Date  // ISO8601, Zulu
//    let annotations: Bool
//    let coverImage: URL  // or false
    let isEvangelist: Bool
    let followsYou: Bool
    let youFollow: Bool

    /**
     If an Account is muted, the intended effect is that you will no longer see their posts
     unless they they mention you.
     */
    let isMuted: Bool

    /**
     If an Account is silenced, they are dead to you:

     - You won't see any of their posts, ever.
     - You won't even see any posts that _mention_ them! (Unless those posts mention you, maybe?)
     */
    let isSilenced: Bool

    var fullName: String {
        // (jeremy-w/2017-03-20)TODO: Respect user's preferences for name ordering
        var fullName = name.first
        if !fullName.isEmpty && !name.last.isEmpty {
            fullName += " "
        }
        fullName += name.last
        return fullName
    }
}


extension Account {
    static func makeFake(username: String = "someone") -> Account {
        return Account(
            id: "123456789",
            username: username,
            name: (
                first: "Someone",
                last: "Fake",
                display: "someone"),
            avatarURL: Account.defaultAvatarURL,
            verified: nil,
            descriptionMarkdown: "just somebody",
            descriptionHTML: "<p>just somebody</p>",
            timezone: "US/Eastern",
            counts: [:],
            createdAt: Date(),
            isEvangelist: false,
            followsYou: false,
            youFollow: false,
            isMuted: false,
            isSilenced: false)
    }

    static func makePrivate() -> Account {
        let privateThing = NSLocalizedString("Private", comment: "private thing")
        return Account(
            id: privateThing,
            username: privateThing,
            name: (first: privateThing, last: privateThing, display: privateThing),
            avatarURL: Account.defaultAvatarURL,
            verified: nil,
            descriptionMarkdown: "",
            descriptionHTML: "",
            timezone: "",
            counts: [:],
            createdAt: Date(),
            isEvangelist: false,
            followsYou: false,
            youFollow: false,
            isMuted: false,
            isSilenced: false)
    }
}
