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
                print("expected string key and int-convertible value, found: \(header)")
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

class TenCenturiesPostRepository: PostRepository {
    let session: URLSession
    init(session: URLSession) {
        self.session = session
    }

    static let baseURL = URL(string: "https://api.10centuries.org")!

    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: stream.view.path, relativeTo: TenCenturiesPostRepository.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = stream.view.queryItems
        let request = URLRequest(url: components.url!)
        print("API: INFO: BEGIN \(request.url)")
        let task = session.dataTask(with: request) { (data, response, error) in
            let result = Result.of { () throws -> [Post] in do {
                guard let response = response as? HTTPURLResponse else {
                    throw TenCenturiesError.notHTTP(url: url)
                }
                /*
                 Rate limit headers look like:

                 X-RateLimit-Limit: 500
                 X-RateLimit-Remaining: 490
                 X-RateLimit-Reset: 2866
                 */
                let limits = RateLimit(headers: response.allHeaderFields)
                print("API: INFO: END \(url): \(response.statusCode): \(data) \(error) "
                    + "- RATELIMIT: \(limits.map { String(reflecting: $0) } ?? "(headers not found)")")

                guard let data = data else {
                    throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                }

                guard error == nil else {
                    throw error!
                }

                let object = try JSONSerialization.jsonObject(with: data, options: [])
//                print("API: VDEBUG: \(url): \(String(reflecting: object))")

                guard let dict = object as? [String: Any]
                , let body = dict["data"] as? [[String: Any]]
                else {
                    throw TenCenturiesError.badResponse(url: url, data: data, comment: "bogus object in body")
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
            }}
            print("API: DEBUG: \(request.url): Result: \(result)")
            completion(result)
        }
        task.resume()
    }
}
