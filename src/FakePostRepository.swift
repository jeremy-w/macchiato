class FakePostRepository: PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.success((0 ..< 10).map { _ in Post.makeFake() }))
    }

    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.failure(notYetImplemented))
    }
}
