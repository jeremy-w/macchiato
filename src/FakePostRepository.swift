class FakePostRepository: PostRepository {
    func find(stream: Stream, options: [PostRepositoryFindOption] = [], completion: @escaping (Result<[Post]>) -> Void) {
        completion(.success((0 ..< 10).map { _ in Post.makeFake() }))
    }

    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.failure(TenCenturiesError.api(code: 420, text: "Fake backend does not support posting!", comment: "")))
    }

    func delete(post: Post, completion: @escaping (Result<Void>) -> Void) {
        completion(.success(Void()))
    }

    func toggleStarred(post: Post, by: String, completion: @escaping (Result<[Post]>) -> Void) {
        var updated = post
        updated.you.starred = !post.you.starred
        completion(.success([updated]))
    }

    func pin(post: Post, color: Post.PinColor?, by persona: String, completion: @escaping (Result<[Post]>) -> Void) {
        var updated = post
        updated.you.pinned = color
        completion(.success([updated]))
    }

    func repost(post: Post, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.failure(TenCenturiesError.api(code: 420, text: "Fake backend does not support reposting!", comment: "")))
    }
}
