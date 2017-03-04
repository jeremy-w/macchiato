import Foundation

class TenCenturiesAccountRepository: AccountRepository, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }

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

        let text: String
        if let descDict = try? unpack(dict, "description") as JSONDictionary {
            text = (try? unpack(descDict, "text")) ?? ""
        } else {
            text = ""
        }

        return Account(
            id: String(describing: try unpack(dict, "id") as Any),
            username: try unpack(dict, "username"),
            name: (first: try unpack(nameDict, "first_name"), last: try unpack(nameDict, "last_name"), display: try unpack(nameDict, "display")),
            avatarURL: parseAvatarURL(dict["avatar_url"]),
            verified: verified,
            description: text,
            timezone: try unpack(dict, "timezone"),
            counts: try unpack(dict, "counts"))
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
}
