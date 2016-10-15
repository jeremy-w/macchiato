protocol PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void)
    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void)
}
