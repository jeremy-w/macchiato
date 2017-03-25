import Foundation

class TenCenturiesAccountRepository: AccountRepository, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }


    // MARK: - Retrieves accounts
    func account(id: String, completion: @escaping (Result<Account>) -> Void) {
        let path = "/users/" + id
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

    static func parseAccount(from dict: JSONDictionary) throws -> Account {
        let nameDict = try unpack(dict, "name") as JSONDictionary

        let verifiedDict = try unpack(dict, "verified") as JSONDictionary
        let verified: URL?
        if try unpack(verifiedDict, "is_verified") {
            verified = URL(string: try unpack(verifiedDict, "url"))
        } else {
            verified = nil
        }

        let descriptionMarkdown: String
        let descriptionHTML: String
        if let descDict = try? unpack(dict, "description") as JSONDictionary {
            descriptionMarkdown = (try? unpack(descDict, "text")) ?? ""
            descriptionHTML = (try? unpack(descDict, "html")) ?? ""
        } else {
            descriptionMarkdown = ""
            descriptionHTML = ""
        }

        let defaultDate = Date.distantPast
        let created = (try? unpack(dict, "created_at")).flatMap({ parseISODate(from: $0) }) ?? defaultDate

        let isEvangelist = (try? unpack(dict, "evangelist")) ?? false
        let followsYou = (try? unpack(dict, "follows_you")) ?? false
        let youFollow = (try? unpack(dict, "you_follow")) ?? false
        let isMuted = (try? unpack(dict, "is_muted")) ?? false
        let isSilenced = (try? unpack(dict, "is_silenced")) ?? false

        return Account(
            id: String(describing: try unpack(dict, "id") as Any),
            username: try unpack(dict, "username"),
            name: (first: try unpack(nameDict, "first_name"), last: try unpack(nameDict, "last_name"), display: try unpack(nameDict, "display")),
            avatarURL: parseAvatarURL(dict["avatar_url"]),
            verified: verified,
            descriptionMarkdown: descriptionMarkdown,
            descriptionHTML: descriptionHTML,
            timezone: try unpack(dict, "timezone"),
            counts: try unpack(dict, "counts"),
            createdAt: created,
            isEvangelist: isEvangelist,
            followsYou: followsYou,
            youFollow: youFollow,
            isMuted: isMuted,
            isSilenced: isSilenced
        )
    }

    static func parseAvatarURL(_ hopefullyString: Any?) -> URL {
        guard let string = hopefullyString as? String else {
            return Account.defaultAvatarURL
        }

        guard let url = URL(string: "https:" + string) else {
            return Account.defaultAvatarURL
        }
        return url
    }


    // MARK: - Un/Follows accounts
    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(toBeFollowing: true, accountWithID: accountWithID, completion: completion)
    }

    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        update(toBeFollowing: false, accountWithID: accountWithID, completion: completion)
    }

    /** Calls the 10C API to edit following.

     To follow: POST /users/follow { "follow_id": 53 }; returns updated account for ID (with you_follow updated)
     To unfollow: DELETE /users/follow { "follow_id": 53 }; returns update account for ID (with you_follow updated)
     */
    private func update(toBeFollowing: Bool, accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        let url = URL(string: "/users/follow", relativeTo: TenCenturies.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = toBeFollowing ? "POST" : "DELETE"
        request.httpBody = try! JSONSerialization.data(withJSONObject: ["follow_id": accountWithID], options: [])

        let _ = send(request: request) { (result) in
            do {
                let dict = try result.unwrap()
                let account = try TenCenturiesAccountRepository.parseAccount(from: dict)
                completion(.success(account))
            } catch {
                completion(.failure(error))
            }
        }
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
