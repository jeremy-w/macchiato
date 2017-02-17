import Foundation

typealias JSONDictionary = [String: Any]

let notYetImplemented = NSError(domain: "notyetimplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not Yet Implemented"])

func unpack<T>(_ obj: JSONDictionary, _ field: String, default: T? = nil) throws -> T {
    guard let value = obj[field] else {
        guard let defaultValue = `default` else {
            throw TenCenturiesError.missingField(field: field, object: obj)
        }
        return defaultValue
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

        case .private_:
            return "/content/blurbs/private"

        case .starred:
            return "/content/blurbs/stars"

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

    // MARK: - Parses posts from a stream
    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, options: [PostRepositoryFindOption] = [], completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: stream.view.path, relativeTo: TenCenturies.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let query = queryItems(for: options) + stream.view.queryItems
        components.queryItems = query.isEmpty ? nil : query
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

    func queryItems(for options: [PostRepositoryFindOption]) -> [URLQueryItem] {
        return options.map { (option: PostRepositoryFindOption) -> URLQueryItem in
            switch option {
            case let .atMost(count):
                return URLQueryItem(name: "count", value: "\(count)")

            case let .before(date):
                return URLQueryItem(name: "before_unix", value: String(describing: date.timeIntervalSince1970))

            case let .after(date):
                return URLQueryItem(name: "since_unix", value: String(describing: date.timeIntervalSince1970))
            }
        }
    }

    func parsePosts(from posts: [JSONDictionary]) throws -> [Post] {
        return posts.map { post in
            do {
                return try parsePost(from: post)
            } catch {
                return Post.displayingRawJSON(post, errorMessage: TenCenturiesError.describe(error))
            }
        }
    }

    func parsePost(from post: JSONDictionary) throws -> Post {
        let postID = String(describing: try unpack(post, "id") as Any)
        let you = try parseYou(from: post)
        let isPrivate = you.cannotSee

        let accounts = try unpack(post, "account", default: []) as [JSONDictionary]
        let account: Account?
        do {
            account = try accounts.first.map { try TenCenturiesAccountRepository.parseAccount(from: $0) }
        } catch {
            print("PARSE: ERROR: Failed to parse account from \(accounts): \(error)")
            account = Account.makeFake()
        }

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

        let mentions: [JSONDictionary]
        do {
            mentions = try unpack(post, "mentions")
        } catch {
            mentions = []
        }

        let defaultDate = Date()
        let markdown: String?
        let html: String?
        if let content = try? unpack(post, "content") as JSONDictionary {
            markdown = try? unpack(content, "text")
            html = try? unpack(content, "html")
        } else if isPrivate {
            markdown = NSLocalizedString("*Post Is Private*", comment: "private post Markdown content")
            html = NSLocalizedString("<em>Post Is Private</em>", comment: "private post HTML content")
        } else {
            markdown = nil
            html = nil
        }

        let parentID = try? unpack(post, "parent_id") as String
        return Post(
            id: postID,
            account: account ?? (isPrivate ? Account.makePrivate() : Account.makeFake()),
            date: Date(timeIntervalSince1970: (try? unpack(post, "created_unix")) ?? defaultDate.timeIntervalSince1970),
            content: markdown ?? "—",
            html: html ?? "<p>—</p>",
            privacy: (try? unpack(post, "privacy")) ?? "—",
            thread: thread,
            parentID: parentID,
            client: (try? unpack(unpack(post, "client"), "name")) ?? "—",
            mentions: (try? parseMentions(from: mentions)) ?? [],
            updated: Date(timeIntervalSince1970: (try? unpack(post, "updated_unix")) ?? defaultDate.timeIntervalSince1970),
            deleted: (try? unpack(post, "is_deleted")) ?? false,
            you: you)
    }

    func parseYou(from post: JSONDictionary) throws -> Post.You {
        // Invisible posts have only visible, muted, and deleted.
        let pinColor: Post.PinColor?
        if let pinned = post["you_pinned"] {
            pinColor = parseYouPinned(pinned)
        } else {
            pinColor = nil
        }

        return Post.You(
            wereMentioned: try unpack(post, "is_mention", default: false),
            starred: try unpack(post, "you_starred", default: false),
            pinned: pinColor,
            reposted: try unpack(post, "you_reposted", default: false),  // docs say "you_reblurbed" but are wrong
            muted: try unpack(post, "is_muted"),
            cannotSee: try !unpack(post, "is_visible"))
    }

    func parseYouPinned(_ rawPinned: Any) -> Post.PinColor? {
        if rawPinned is Bool {
            return nil
        }

        guard let text = rawPinned as? String else { return nil }

        let pins = ["pin.black", "pin.blue", "pin.red", "pin.green", "pin.orange", "pin.yellow"]
        let colors: [Post.PinColor] = [.black, .blue, .red, .green, .orange, .yellow]
        assert(pins.count == colors.count, "pins.count \(pins.count) != colors.count \(colors.count)")
        return pins.index(of: text).map { colors[$0] }
    }

    func parseMentions(from array: [JSONDictionary]) throws -> [Post.Mention] {
        return try array.map { try parse(mention: $0) }
    }

    func parse(mention: JSONDictionary) throws -> Post.Mention {
        func stripPrefixedAtSign(from string: String) -> String {
            guard string.hasPrefix("@") else { return string }
            return string.substring(from: string.index(after: string.startIndex))
        }

        return Post.Mention(
            name: stripPrefixedAtSign(from: try unpack(mention, "name")),
            id: String(describing: try unpack(mention, "id") as Any),
            current: stripPrefixedAtSign(from: try unpack(mention, "current")))
    }


    // MARK: - Saves posts
    func save(post: EditingPost, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "/content/write", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        let json: JSONDictionary = [
            "content": post.content,
            "post_id": post.updating ?? "",
            "reply_to": post.replyTo ?? "",
            ]
        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: json, options: [])
    }


    // MARK: - Deletes posts
    func delete(post: Post, completion: @escaping (Result<Void>) -> Void) {
        let url = URL(string: "/content/\(post.id)", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _ = send(request: request) { result in
            do {
                let _ = try result.unwrap()
                completion(.success(Void()))
            } catch {
                completion(.failure(error))
            }
        }
    }


    // MARK: - Takes sundry other actions
    func star(post: Post, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "/content/star/\(post.id)", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _ = send(request: request) { (result) in
            do {
                let wrapper = try result.unwrap()
                let posts = try self.parsePosts(from: unpack(wrapper, "data"))
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func pin(post: Post, color: Post.PinColor?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "/content/pin/\(post.id)", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        if let pin = color {
            request.httpMethod = "POST"
            request.httpBody = try! JSONSerialization.data(
                withJSONObject: [ "color": hex(for: pin) ],
                options: [])
        } else {
            request.httpMethod = "DELETE"
        }
        let _ = send(request: request) { (result) in
            do {
                let wrapper = try result.unwrap()
                let posts = try self.parsePosts(from: unpack(wrapper, "data"))
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func repost(post: Post, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "/content/repost/\(post.id)", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _ = send(request: request) { (result) in
            do {
                let wrapper = try result.unwrap()
                let posts = try self.parsePosts(from: unpack(wrapper, "data"))
                completion(.success(posts))
            } catch {
                completion(.failure(error))
            }
        }
    }
}



func hex(for pin: Post.PinColor) -> String {
    switch pin {
    case .black: return "#000000"
    case .blue: return "#0000ff"
    case .green: return "#00ff00"
    case .orange: return "#ffa500"
    case .red: return "#ff0000"
    case .yellow: return "#ffff00"
    }
}
