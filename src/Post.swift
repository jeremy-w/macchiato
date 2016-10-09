import Foundation

struct Post {
    let id: String
    let author: String
    let date: Date
    let content: String

    static func makeFake() -> Post {
        return Post(
            id: UUID().uuidString,
            author: pick(["@someone", "@someone_else", "@not_you"]),
            date: Date(),
            content: Array(repeating: "This is some awesome text.", count: randomNumber(in: 1 ..< 50)).joined(separator: " "))
    }
}
