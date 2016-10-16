protocol PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void)
    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void)
    func delete(post: Post, completion: @escaping (Result<Void>) -> Void)

    func star(post: Post, completion: @escaping (Result<[Post]>) -> Void)
    func pin(post: Post, color: Post.PinColor?, completion: @escaping (Result<[Post]>) -> Void)
    func repost(post: Post, completion: @escaping (Result<[Post]>) -> Void)
}
