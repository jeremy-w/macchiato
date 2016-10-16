import Foundation

struct Post {
    let id: String
    let author: String
    let date: Date
    var content: String

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
            updated: now,
            deleted: false,
            you: You())
    }

    let privacy: String
    let thread: (root: String, replyTo: String)?
    let parentID: String?
    let client: String

    /// If the same as `date`, then the post has not been edited.
    var updated: Date
    var deleted: Bool

    var you: You

    struct You {
        var wereMentioned: Bool = false
        var starred: Bool = false
        var pinned: PinColor?
        var reposted: Bool = false
        var muted: Bool = false
        var cannotSee: Bool = false
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


struct EditingPost {
    var content: String

    let channel = 1
    let updating: String?
    let replyTo: String?
}
