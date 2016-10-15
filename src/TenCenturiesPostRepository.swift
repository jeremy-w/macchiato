import Foundation

typealias JSONDictionary = [String: Any]

let notYetImplemented = NSError(domain: "notyetimplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not Yet Implemented"])

func unpack<T>(_ obj: JSONDictionary, _ field: String) throws -> T {
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

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .thread(root):
            return [URLQueryItem(name: "post_id", value: root)]

        default:
            return nil
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

    // MARK: - Parses posts from a stream
    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: stream.view.path, relativeTo: TenCenturies.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = stream.view.queryItems
        let request = URLRequest(url: components.url!)

        let _ = send(request: request) { result in
            let result = Result.of { () -> [Post] in
                let parent = try result.unwrap()
                let data: [JSONDictionary] = try unpack(parent, "data")
                let posts = try self.parsePosts(from: data)
                return posts
            }
            completion(result)
        }
    }

    func parsePosts(from posts: [JSONDictionary]) throws -> [Post] {
        return try posts.map { post in try parsePost(from: post) }
    }

    func parsePost(from post: JSONDictionary) throws -> Post {
        let accounts = try unpack(post, "account") as [JSONDictionary]
        let account = accounts.first ?? ["username": "«unknown»"]

        // Doing try? "thread" then try? wrapper.map leads to a doubly-optional (String, String)??
        // as the Optional.map and try? gang-up on things. Yuck. Could flatMap at the end, but pretty unreadable by that point.
        let thread: (root: String, replyTo: String)?
        do {
            let wrapper: JSONDictionary = try unpack(post, "thread")
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


    // MARK: - Saves posts
    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "/content", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpBody = json(for: post)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let _ = send(request: request) { result in
            let result = Result.of { () -> [Post] in
                let wrapper = try result.unwrap()
                let data: [JSONDictionary] = try unpack(wrapper, "data")
                return try self.parsePosts(from: data)
            }
            completion(result)
        }
    }

    func json(for post: EditingPost) -> Data {
        var json: JSONDictionary = [
            "content": post.content,
            "channel": post.channel,
            ]
        if let postID = post.updating.flatMap({ UIntMax($0, radix: 10) }) {
            json["post_id"] = postID
        }
        if let replyTo = post.replyTo.flatMap({ UIntMax($0, radix: 10) }) {
            json["reply_to"] = replyTo
        }
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: json, options: [])
    }
}
