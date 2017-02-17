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
    let description: String
    let timezone: String

    let counts: [String: Int]  // following, followers, stars, posts of various sizes
//    let createdAt: Date  // ISO8601, Zulu
//    let annotations: Bool
//    let coverImage: URL  // or false
//    let evangelist: Bool
//    let followsYou: Bool
//    let youFollow: Bool
//    let isMuted: Bool
//    let isSilenced: Bool
}


extension Account {
    static func makeFake() -> Account {
        return Account(
            id: "123456789",
            username: "someone",
            name: (
                first: "Someone",
                last: "Fake",
                display: "someone"),
            avatarURL: Account.defaultAvatarURL,
            verified: nil,
            description: "just somebody",
            timezone: "US/Eastern",
            counts: [:])
    }

    static func makePrivate() -> Account {
        let privateThing = NSLocalizedString("Private", comment: "private thing")
        return Account(
            id: privateThing,
            username: privateThing,
            name: (first: privateThing, last: privateThing, display: privateThing),
            avatarURL: Account.defaultAvatarURL,
            verified: nil,
            description: "",
            timezone: "",
            counts: [:])
    }
}
