import Foundation

struct Post {
    let id: String
    let author: String
    let date: Date
    let content: String

    static func makeFake() -> Post {
        let now = Date()
        return Post(
            id: UUID().uuidString,
            author: pick(["@someone", "@someone_else", "@not_you"]),
            date: now,
            content: Array(repeating: "This is some awesome text.", count: randomNumber(in: 1 ..< 50)).joined(separator: " "),
            privacy: "visibility.public",
            thread: nil,
            client: "Magicat",
            updated: now)
    }

    let privacy: String
    let thread: (root: String, replyTo: String)?
    let client: String

    /// If the same as `date`, then the post has not been edited.
    let updated: Date
}
