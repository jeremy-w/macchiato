import Foundation
import GameplayKit

class Stream {
    let name: String
    let posts: [Post]
    init(name: String, posts: [Post]) {
        self.name = name
        self.posts = posts
    }

    static let global = Stream(name: "Global", posts: (0 ..< 10).map { _ in Post.makeFake() })
}


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
