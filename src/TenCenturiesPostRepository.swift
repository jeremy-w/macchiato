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
            return "/api/posts/global"

        case .home:
            return "/api/posts/home"

        case .pinned:
            return "/api/posts/pins"

        case .mentions:
            return "/api/posts/mentions"

        case .interactions:
            return "/api/posts/interactions"

        case .starters:
            return "/api/posts/starters"

        case .private_:
            return "/api/posts/private"

        case .starred:
            return "/api/posts/stars"

        case let .thread(root):
            return "/api/posts/\(root)/thread"
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
        let request = URLRequest(url: type(of: self).url(for: stream.view, with: options))

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

    static func url(for view: Stream.View, with options: [PostRepositoryFindOption] = []) -> URL {
        // 10Cv5 example for global:
        // https://nice.social/api/posts/global?types=post.article,post.blog,post.bookmark,post.note,post.photo,post.quotation,post.todo&since=1554925972&count=75
        let url = URL(string: view.path, relativeTo: TenCenturies.baseURL)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        // (jeremy-w/2019-04-13)TODO: 10Cv5: Let the user opt out of seeing some kinds of posts.
        let postKindsSelectedByUserOneDayMaybe = Set(Post.Flavor.allCases).streamQueryItem
        let query = queryItems(for: options) + view.queryItems + [postKindsSelectedByUserOneDayMaybe]
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    static func queryItems(for options: [PostRepositoryFindOption]) -> [URLQueryItem] {
        return options.map { (option: PostRepositoryFindOption) -> URLQueryItem in
            switch option {
            case let .atMost(count):
                return URLQueryItem(name: "count", value: "\(count)")

            case let .before(date):
                return URLQueryItem(name: "before_unix", value: String(describing: date.timeIntervalSince1970))

            case let .after(date):
                return URLQueryItem(name: "since_unix", value: String(describing: date.timeIntervalSince1970))

            case let .flavors(flavors):
                return flavors.streamQueryItem
            }
        }
    }

    func parsePosts(from posts: [JSONDictionary]) throws -> [Post] {
        return posts.compactMap
            { post in
                do {
                    return try parsePost(from: post)
                } catch {
                    print("POSTS: WARNING: Caught parse error:", error)
                    return nil
                }
            }
    }

    func parsePost(from post: JSONDictionary) throws -> Post {
        let postID = String(describing: try unpack(post, "guid") as Any)

        // (2019-04-12)!!!: Likely bug: "mentions" can be an object, not an array, when there's just one
        let mentions: [Post.Mention]
        if let rawMentionsArray = try? unpack(post, "mentions") as [JSONDictionary],
            let parsedMentions = try? parseMentions(from: rawMentionsArray) {
            mentions = parsedMentions
        } else if let rawSingularMention = try? unpack(post, "mentions") as JSONDictionary,
            let mention = try? parse(mention: rawSingularMention) {
            mentions = [mention]
        } else {
            mentions = []
        }

        let geo = parseGeo(from: post)

        let you = try parseYou(from: post, mentions: mentions)
        let isPrivate = you.cannotSee

        let rawAccount = try unpack(post, "persona", default: [:]) as JSONDictionary
        let account: Account
        do {
            account = try TenCenturiesAccountRepository.parseAccount(from: rawAccount)
        } catch {
            // (jeremy-w/2019-04-12)TODO: Could a post's author be somehow private, so that we need a private account placeholder?
            // Hard to encounter the edge cases around post visibility.
            print("PARSE: ERROR: Failed to parse account from \(rawAccount): \(error)")
            account = Account.makeFake()
        }

        let thread: (root: String, replyTo: String)?
        do {
            let rootGUID = try unpack(unpack(post, "thread"), "guid") as String
            let replyToGUID = try unpack(post, "reply_to") as String
            thread = (root: rootGUID, replyTo: replyToGUID)
        } catch {
            thread = nil
        }

        var html = try? unpack(post, "content") as String
        var markdown = try? unpack(post, "text") as String
        let lacksContent = html != nil && markdown != nil
        if lacksContent && isPrivate {
            markdown = NSLocalizedString("*Post Is Private*", comment: "private post Markdown content")
            html = NSLocalizedString("<em>Post Is Private</em>", comment: "private post HTML content")
        }

        if isPrivate && lacksContent {
            print("POSTS: INFO: Skipping private post without actual content: Post ID", postID)
            throw TenCenturiesError.other(
                message: NSLocalizedString("Skipping private post", comment: "error message"),
                info: post)
        }

        // This is mostly "0" it seems, so we only show it if there's a |parent|, too.
        let parentID = post["parent_id"].map({ String(describing: $0) })
        let parent: Post?
        if parentID != nil, let parentDict = post["parent"] as? JSONDictionary {
            parent = try parsePost(from: parentDict)
        } else {
            parent = nil
        }

        let defaultDate = Date()
        let updated = Date(timeIntervalSince1970: (try? unpack(post, "updated_unix")) ?? defaultDate.timeIntervalSince1970)
        let published = Date(timeIntervalSince1970: (try? unpack(post, "publish_unix")) ?? defaultDate.timeIntervalSince1970)
        // (jeremy-w/2019-04-12)TODO: Confirm 10Cv5 dropped "created_unix" from Post
        let created = (try? unpack(post, "created_unix") as TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? published

        let stars = parseStars(from: post["stars"])
        // (jeremy-w/2019-04-12)TODO: Add 10v5 "title" field to Post and show it
        return Post(
            id: postID,
            account: account,
            content: markdown ?? "—",
            html: html ?? "<p>—</p>",
            privacy: (try? unpack(post, "privacy")) ?? "—",
            thread: thread,
            parentID: (parent != nil) ? parentID : String?.none,
            client: (try? parseClientName(from: post)),
            mentions: mentions,
            created: created,
            updated: updated,
            published: published,
            deleted: (try? unpack(post, "is_deleted")) ?? false,
            you: you,
            stars: stars,
            parent: parent,
            geo: geo)
    }

    func parseGeo(from post: JSONDictionary) -> Post.Geo? {
        guard let geo = try? unpack(unpack(post, "meta"), "geo") as JSONDictionary else {
            return nil
        }

        let name = try? unpack(geo, "description") as String

        // 10Cv5 sends "false" for missing values.
        // That coerces to Double as 0.0. And answers yes to `is Double`. Yay.
        // I'm not convinced we'll still parse an actual lat/lon or altitude of 0 correctly. :(
        let lat: Double? = geo["latitude"] is Bool ? nil : try? unpack(geo, "latitude")
        let lng: Double? = geo["longitude"] is Bool ? nil : try? unpack(geo, "longitude")
        let altitude: Double? = geo["altitude"] is Bool ? nil : try? unpack(geo, "altitude")

        return Post.Geo(name: name ?? "", latitude: lat, longitude: lng, altitude: altitude)
    }

    func parseClientName(from post: JSONDictionary) throws -> String? {
        guard let client = try? unpack(post, "client") as JSONDictionary else {
            return nil
        }

        return try unpack(client, "name")
    }

    /**
     Parses information about the logged-in user's relationship to the post.

     If you're not logged-in, this is all dummy data.
     */
    func parseYou(from post: JSONDictionary, mentions: [Post.Mention]) throws -> Post.You {
        // (jeremy-w/2019-04-12)TODO: Mark Post.you as optional.
        /**
         Example JSON:

         ```
             "attributes": {
             "pin": "pin.none",
             "starred": false,
             "muted": false,
             "points": 0
         }
         ```

         I have no idea what "points" is.
         */
        guard let attributes = try? unpack(post, "attributes") as JSONDictionary else {
            return Post.You()
        }

        // Invisible posts have only visible, muted, and deleted.
        let pinColor = attributes["pin"].flatMap(parseYouPinned)

        let wereMentioned = mentions.contains { $0.isYou }
        return Post.You(
            wereMentioned: wereMentioned,
            starred: try unpack(attributes, "starred", default: false),
            pinned: pinColor,

            // (jeremy-w/2019-04-12)TODO: Does 10Cv5 not have / track reposts?
            reposted: false,

            muted: try unpack(attributes, "muted", default: false),

            // (jeremy-w/2019-04-12)TODO: Does 10Cv5 not have a dedicated "is_visible" field?
            cannotSee: try !unpack(post, "visible", default: true))
    }

    func parseYouPinned(_ rawPinned: Any) -> Post.PinColor? {
        if rawPinned is Bool {
            return nil
        }

        guard let text = rawPinned as? String else { return nil }

        let pins = ["pin.black", "pin.blue", "pin.red", "pin.green", "pin.orange", "pin.yellow"]
        let colors: [Post.PinColor] = [.black, .blue, .red, .green, .orange, .yellow]
        assert(pins.count == colors.count, "pins.count \(pins.count) != colors.count \(colors.count)")
        return pins.firstIndex(of: text).map { colors[$0] }
    }

    func parseMentions(from array: [JSONDictionary]) throws -> [Post.Mention] {
        return try array.map { try parse(mention: $0) }
    }

    func parse(mention: JSONDictionary) throws -> Post.Mention {
        func stripPrefixedAtSign(from string: String) -> String {
            guard string.hasPrefix("@") else { return string }
            return String(string[string.index(after: string.startIndex)...])
        }

        let name = stripPrefixedAtSign(from: try unpack(mention, "as"))
        return Post.Mention(
            name: name,
            id: String(describing: try unpack(mention, "guid") as Any),
            current: name,
            isYou: try unpack(mention, "is_you", default: false))
    }

    func parseStars(from json: Any?) -> [Post.Star] {
        guard let stars = json as? [JSONDictionary] else {
            return []
        }

        var parsed: [Post.Star] = []
        parsed.reserveCapacity(stars.count)
        for dict in stars {
            do {
                let avatarURL = TenCenturiesAccountRepository.parseAvatarURL(dict["avatar_url"])
                let id = String(describing: try unpack(dict, "id") as Any)
                let atName = try unpack(dict, "name") as String
                let starTimestamp = try unpack(dict, "starred_unix") as TimeInterval
                let star = Post.Star(avatarURL: avatarURL, userID: id, userAtName: atName, starredAt: Date(timeIntervalSince1970: starTimestamp))
                parsed.append(star)
            } catch {
                print("POST/STAR: ERROR: Failed to parse a star record:", error, "- record", dict)
            }
        }
        return parsed
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
        let url = URL(string: "/content", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.httpBody = try! JSONSerialization.data(
            withJSONObject: [ "post_id": post.id ],
            options: [])
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
    func toggleStarred(post: Post, completion: @escaping (Result<[Post]>) -> Void) {
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

extension Set where Element == Post.Flavor {
    var streamQueryItem: URLQueryItem {
        let commaSeparatedFlavorStrings = self.map { $0.rawValue }.joined(separator: ",")
        return URLQueryItem(name: "types", value: commaSeparatedFlavorStrings)
    }
}
