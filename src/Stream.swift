class Stream {
    let name: String
    let posts: [Post]
    init(name: String, posts: [Post]) {
        self.name = name
        self.posts = posts
    }

    static let global = Stream(name: "Global", posts: (0 ..< 10).map { _ in Post.makeFake() })
}
