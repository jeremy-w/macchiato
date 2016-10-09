class FakePostRepository: PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.success((0 ..< 10).map { _ in Post.makeFake() }))
    }
}
