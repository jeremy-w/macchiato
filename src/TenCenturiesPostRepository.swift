import Foundation

typealias JDict = [String: Any]

let notYetImplemented = NSError(domain: "notyetimplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not Yet Implemented"])

func unpack<T>(_ obj: JDict, _ field: String) throws -> T {
    guard let value = obj[field] else {
        throw TenCenturiesError.missingField(field: field, object: obj)
    }

    guard let cast = value as? T else {
        throw TenCenturiesError.badFieldType(field: field, expected: T.self, found: value, in: obj)
    }

    return cast
}

extension Stream.View {
    var path: String {
        switch self {
        case .global:
            return "/content/blurbs/global"

        case .home:
            return "/content/blurbs/home"

        case .pinned:
            return "/content/blurbs/pins"

        case .mentions:
            return "/content/blurbs/mentions"

        case .interactions:
            return "/content/blurbs/interactions"

        case .starters:
            return "/content/blurbs/starters"

        case .thread:
            // Requires -d post_id=post.thread.root
            // Alternatively, hit /content/social/thread with -d thread_id=post.thread.root.
            return "/content/blurbs/thread"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .thread(root):
            return [URLQueryItem(name: "post_id", value: root)]

        default:
            return []
        }
    }
}


class TenCenturiesPostRepository: PostRepository, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }

    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: stream.view.path, relativeTo: TenCenturies.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = stream.view.queryItems
        let request = URLRequest(url: components.url!)

        let _ = send(request: request) { result in
            let result = Result.of { () -> [Post] in
                let parent = try result.unwrap()
                let data: [JDict] = try unpack(parent, "data")
                let posts = try self.parsePosts(from: data, source: url)
                return posts
            }
            completion(result)
        }
    }

    func parsePosts(from posts: [JDict], source url: URL) throws -> [Post] {
        return try posts.map { post in try parsePost(from: post) }
    }

    func parsePost(from post: JDict) throws -> Post {
        let accounts = try unpack(post, "account") as [JDict]
        let account = accounts.first ?? ["username": "«unknown»"]

        // Doing try? "thread" then try? wrapper.map leads to a doubly-optional (String, String)??
        // as the Optional.map and try? gang-up on things. Yuck. Could flatMap at the end, but pretty unreadable by that point.
        let thread: (root: String, replyTo: String)?
        do {
            let wrapper: JDict = try unpack(post, "thread")
            func cast(_ value: Double) -> String {
                return String(UInt64(value))
            }
            thread = try (root: cast(unpack(wrapper, "thread_id")), replyTo: cast(unpack(wrapper, "reply_to")))
        } catch {
            thread = nil
        }

        let parentID = try? unpack(post, "parent_id") as String
        return Post(
            id: String(describing: try unpack(post, "id") as Any),
            author: try unpack(account, "username"),
            date: Date(timeIntervalSince1970: try unpack(post, "created_unix")),
            content: try unpack(unpack(post, "content"), "text"),
            privacy: try unpack(post, "privacy"),
            thread: thread,
            parentID: parentID,
            client: try unpack(unpack(post, "client"), "name"),
            updated: Date(timeIntervalSince1970: try unpack(post, "updated_unix")))
    }
}
