import Foundation

protocol PostRepository {
    func find(stream: Stream, options: [PostRepositoryFindOption], completion: @escaping (Result<[Post]>) -> Void)
    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void)
    func delete(post: Post, completion: @escaping (Result<Void>) -> Void)

    func toggleStarred(post: Post, by persona: String, completion: @escaping (Result<[Post]>) -> Void)
    func pin(post: Post, color: Post.PinColor?, by persona: String, completion: @escaping (Result<[Post]>) -> Void)
    func repost(post: Post, completion: @escaping (Result<[Post]>) -> Void)
}

enum PostRepositoryFindOption {
    case atMost(Int)
    case before(Date)
    case after(Date)
    case flavors(Set<Post.Flavor>)
}
