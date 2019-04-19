import Foundation

class TenCenturiesAccountRepository: AccountRepository, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }


    // MARK: - Retrieves accounts
    func bioForPersona(id: String, completion: @escaping (Result<Account>) -> Void) {
        let path = "/api/account/\(id)/bio"
        guard let url = URL(string: path, relativeTo: TenCenturies.baseURL) else {
            let badURL = TenCenturiesError.badURL(string: path, info: ["relativeTo": TenCenturies.baseURL])
            print("ACCOUNTS: ERROR: Failed to build URL:", String(reflecting: badURL))
            return completion(.failure(badURL))
        }

        let _ = send(request: URLRequest(url: url)) { result in
            let result = Result.of { () -> Account in
                let parent = try result.unwrap()
                let data: [JSONDictionary] = try unpack(parent, "data")
                guard let accountJSON = data.first else {
                    throw TenCenturiesError.missingField(field: ".data[0]", object: parent)
                }
                return try TenCenturiesAccountRepository.parseAccount(from: accountJSON)
            }
            completion(result)
        }
    }

    /**
     10Cv5 seems to have dropped a lot of fields within a post.
     Did these disappear entirely? Or just not inlined in the post response?

     Example JSON from a post:

     ```
     "persona": {
                   "guid": "07d2f4ec-545f-11e8-99a0-54ee758049c3",
                   "as": "@matigo",
                   "name": "Jason",
                   "avatar": "https://matigo.ca/avatars/jason_fox_box.jpg",
                   "follow": {
                     "url": "https://matigo.ca/feeds/matigo.json",
                     "rss": "https://matigo.ca/feeds/matigo.xml"
                   },
                   "is_active": true,
                   "is_you": false,
                   "profile_url": "https://matigo.ca/profile/matigo",
                   "created_at": "2012-08-01T00:00:00Z",
                   "created_unix": 1343779200,
                   "updated_at": "2018-05-17T19:07:26Z",
                   "updated_unix": 1526584046
                 }
     ```
     */
    static func parseAccount(from dict: JSONDictionary) throws -> Account {
        let guid = String(describing: try unpack(dict, "guid") as Any)

        let rawUsername = try unpack(dict, "as", default: guid)
        let username = rawUsername.hasPrefix("@") ? String(rawUsername.dropFirst(1)) : rawUsername

        let name = try unpack(dict, "name", default: username) as String

        let defaultDate = Date.distantPast
        let created = (try? unpack(dict, "created_at")).flatMap({ parseISODate(from: $0) }) ?? defaultDate

        let followsYou = (try? unpack(dict, "follows_you")) ?? false
        let youFollow = (try? unpack(dict, "you_follow")) ?? false
        let isMuted = (try? unpack(dict, "is_muted")) ?? false
        let isSilenced = (try? unpack(dict, "is_silenced")) ?? false

        return Account(
            id: guid,
            username: username,
            // (jeremy-w/2019-04-12)TODO: Drop structured Account.name tupled in favor of flat "name" string for 10Cv5
            name: (first: "", last: "", display: name),
            avatarURL: parseAvatarURL(dict["avatar"]),
            // (jeremy-w/2019-04-12)TODO: Delete field Account.verified dropped in 10Cv5
            verified: nil,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.descriptionMarkdown dropped in 10Cv5
            descriptionMarkdown: "",
            // (jeremy-w/2019-04-12)TODO: Delete field Account.descriptionHTML dropped in 10Cv5
            descriptionHTML: "",
            // (jeremy-w/2019-04-12)TODO: Delete field Account.timezone dropped in 10Cv5
            timezone: try unpack(dict, "timezone", default: ""),
            // (jeremy-w/2019-04-12)TODO: Delete field Account.counts dropped in 10Cv5
            counts: try unpack(dict, "counts", default: [:]),
            createdAt: created,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.isEvangelist dropped in 10Cv5
            isEvangelist: false,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.followsYou dropped in 10Cv5
            followsYou: followsYou,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.youFollow dropped in 10Cv5
            youFollow: youFollow,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.isMuted dropped in 10Cv5
            isMuted: isMuted,
            // (jeremy-w/2019-04-12)TODO: Delete field Account.isSilenced dropped in 10Cv5
            isSilenced: isSilenced
        )
    }

    static func parseAvatarURL(_ hopefullyString: Any?) -> URL {
        guard let string = hopefullyString as? String else {
            return Account.defaultAvatarURL
        }

        guard let url = URL(string: string) else {
            return Account.defaultAvatarURL
        }
        return url
    }


    // MARK: - Un/Follows accounts
    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .follow, establish: true, accountWithID: accountWithID, completion: completion)
    }

    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .follow, establish: false, accountWithID: accountWithID, completion: completion)
    }


    // MARK: - Un/Mutes accounts
    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .mute, establish: true, accountWithID: accountWithID, completion: completion)
    }

    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .mute, establish: false, accountWithID: accountWithID, completion: completion)
    }


    // MARK: - Un/Silences accounts
    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .silence, establish: true, accountWithID: accountWithID, completion: completion)
    }

    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(relationship: .silence, establish: false, accountWithID: accountWithID, completion: completion)
    }

    /** Calls the 10C API to edit the relationship.
     */
    private func update(
        relationship: EditableAccountRelationship,
        establish: Bool,
        accountWithID: String,
        completion: @escaping (Result<Account>) -> Void
    ) {
        var request = URLRequest(url: relationship.url)
        request.httpMethod = establish ? "POST" : "DELETE"
        request.httpBody = try! JSONSerialization.data(withJSONObject: [relationship.bodyIDKey: accountWithID], options: [])

        let _ = send(request: request) { (result) in
            do {
                let root = try result.unwrap()
                let data: [JSONDictionary] = try unpack(root, "data")
                guard let accountDict = data.first else {
                    throw TenCenturiesError.missingField(field: "data[0]", object: root)
                }
                let account = try TenCenturiesAccountRepository.parseAccount(from: accountDict)
                completion(.success(account))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

private enum EditableAccountRelationship {
    case follow
    case mute
    case silence

    var url: URL {
        let chunk: String
        switch self {
        case .follow:
            chunk = "follow"

        case .mute:
            chunk = "mute"

        case .silence:
            chunk = "silence"
        }

        let url = URL(string: "/users/\(chunk)", relativeTo: TenCenturies.baseURL)!
        return url
    }

    var bodyIDKey: String {
        let key: String
        switch self {
        case .follow:
            key = "follow_id"

        case .mute:
            key = "mute_id"

        case .silence:
            key = "silence_id"
        }
        return key
    }
}

private let isoDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
    return dateFormatter
}()
func parseISODate(from string: String) -> Date? {
    return isoDateFormatter.date(from: string)
}
