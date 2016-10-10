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

struct RateLimit {
    let limit: Int
    let remaining: Int
    let resetsAfter: TimeInterval
    let resetsAt: Date

    init(limit: Int, remaining: Int, resetsAfter: TimeInterval, from: Date = Date()) {
        self.limit = limit
        self.remaining = remaining
        self.resetsAfter = resetsAfter
        self.resetsAt = from + resetsAfter
    }

    init?(headers: [AnyHashable: Any], at date: Date = Date()) {
        var maybeLimit: Int?
        var maybeRemaining: Int?
        var maybeResetsAfter: TimeInterval?

        for header in headers {
            guard let key = header.key as? String
                , let value = header.value as? String
                , let number = Int(value) else {
                continue
            }

            switch key.lowercased() {
            case "x-ratelimit-limit": maybeLimit = number
            case "x-ratelimit-remaining": maybeRemaining = number
            case "x-ratelimit-reset": maybeResetsAfter = TimeInterval(number)
            default: continue
            }
        }

        guard let limit = maybeLimit
        , let remaining = maybeRemaining
        , let resetsAfter = maybeResetsAfter else { return nil }

        self.limit = limit
        self.remaining = remaining
        self.resetsAfter = resetsAfter
        self.resetsAt = date + resetsAfter
    }
}

class TenCenturiesPostRepository: PostRepository, TenCenturiesService {
    let session: URLSession
    let authenticator: TenCenturiesAuthenticator
    init(session: URLSession, authenticator: TenCenturiesAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }

    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: stream.view.path, relativeTo: TenCenturies.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = stream.view.queryItems
        var request = URLRequest(url: components.url!)
        var authenticated = false
        if let token = authenticator.user?.token {
            request.addValue(token, forHTTPHeaderField: "Authorization")
            authenticated = true
        }
        print("API: INFO: BEGIN \(authenticated ? "AUTHENTICATED" : "anonymous") \(request.url)")
        let _ = send(request: request) { result in
            let result = Result.of { () -> [Post] in
                let data = try result.unwrap()
                let posts = try self.parse(data, from: url)
                return posts
            }
            completion(result)
        }
    }

    func parse(_ data: Any, from url: URL) throws -> [Post] {
        guard let body = data as? [[String: Any]] else {
            throw TenCenturiesError.badFieldType(field: "data", expected: [[String: Any]].self, found: data, in: [:])
        }

        return try body.map { post in
            let accounts = try unpack(post, "account") as [JDict]
            let account = accounts.first ?? ["username": "«unknown»"]

            let thread: (root: String, replyTo: String)?
            do {
                let info: JDict = try unpack(post, "thread")
                thread = try (root: unpack(info, "thread_id"), replyTo: unpack(info, "reply_to"))
            } catch {
                thread = nil
            }

            let parentID: String?
            do {
                parentID = try unpack(post, "parent_id") as String
            } catch {
                parentID = nil
            }

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
}
