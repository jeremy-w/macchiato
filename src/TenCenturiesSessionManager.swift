import Foundation
import Security

class TenCenturiesSessionManager {
    let session: URLSession
    let client: UUID
    let user: User?
    init(session: URLSession, client: UUID, user: String? = nil) {
        self.session = session
        self.client = client
        self.user = TenCenturiesSessionManager.load(account: user, client: client)
    }

    struct User {
        let account: String
        let token: String
    }
}


// MARK: - Persists session info to keychain
extension TenCenturiesSessionManager {
    func save(user: User) {
        TenCenturiesSessionManager.updateLastAccount(user.account)
        let dict: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: user.account,
            kSecAttrService: "10Centuries",
            kSecAttrGeneric: client.uuidString.data(using: .utf8),
            kSecValueData: user.token.data(using: .utf8),
        ]
        let status = SecItemAdd(dict, nil)
        guard status == errSecSuccess else {
            print("AUTH: ERROR: Failed to add token to keychain: error \(status) - input \(dict)")
            return
        }
        print("AUTH: INFO: Saved token for \(user.account)")
    }

    /// Nil account means "use the last one we used".
    static func load(account: String?, client: UUID) -> User? {
        guard let account = account ?? lastAccount else {
            print("AUTH: ERROR: No account to look up token for")
            return nil
        }

        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: "10Centuries",
            kSecAttrGeneric: client.uuidString.data(using: .utf8),
            kSecReturnData: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess else {
            print("AUTH: ERROR: Failed to fetch token from keychain: error \(status) - query \(query)")
            return nil
        }
        guard let value = result else {
            print("AUTH: ERROR: Success, but got nil!")
            return nil
        }
        guard let data = value as? Data else {
            print("AUTH: ERROR: Failed understanding returned value of type \(type(of: result))")
            return nil
        }
        guard let token = String(data: data, encoding: .utf8) else {
            print("AUTH: ERROR: Failed decoding user access token string from data")
            return nil
        }
        return User(account: account, token: token)
    }

    static var lastAccount: String? {
        return UserDefaults.standard.string(forKey: "lastAccount")
    }

    static func updateLastAccount(_ name: String) {
        print("AUTH: INFO: Last used account updated to: \(name)")
        UserDefaults.standard.set(lastAccount, forKey: "lastAccount")
    }
}

extension URLRequest {
    mutating func attachURLEncodedFormData(_ queryItems: [URLQueryItem]) {
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // If we have to do this ourselves, or we get into multipart soonish, see:
        // https://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
        var components = URLComponents()
        components.queryItems = queryItems
        let query = components.percentEncodedQuery
        httpBody = query?.data(using: .utf8)
    }
}

extension UUID {
    var simpleString: String {
        return uuidString.lowercased().components(separatedBy: "-").joined()
    }
}


// MARK: - Handle log in/out actions
extension TenCenturiesSessionManager: SessionManager {
    var loggedInAccountName: String? {
        return nil
    }

    func logOut() {
        var request = URLRequest(url: URL(string: "/auth/logout", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        let _ = send(request: request) { _ in }
    }

    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void) {
        var request = URLRequest(url: URL(string: "/auth/login", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        request.attachURLEncodedFormData([
            URLQueryItem(name: "client_guid", value: client.simpleString),
            URLQueryItem(name: "acctname", value: account),
            URLQueryItem(name: "acctpass", value: password)
            ])
        let _ = send(request: request) { (result) in
            let result = Result.of { () -> Bool in
                let data = try result.unwrap()
                let parent = ["data": data]
                let body: [String: Any] = try unpack(parent, "data")
                let token: String = try unpack(body, "token")
                self.save(user: User(account: account, token: token))
                return true
            }
            completion(result)
        }
    }
}

extension TenCenturiesSessionManager: TenCenturiesService {
}
