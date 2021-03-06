import Foundation
import Security

class TenCenturiesSessionManager {
    let session: URLSession
    let clientGUID: String
    fileprivate(set) var user: User? {
        didSet {
            print("SESSION: INFO: Will notify: User did change to:", user as Any)
            NotificationCenter.default.post(name: .loggedInAccountDidChange, object: self)
        }
    }

    /// You will need to define a `static var appClientGUID: String` in the ignored file: TenCenturiesSessionManager+AppClientGUID.swift
    /// to provide your client secret to the app.
    ///
    /// You can find your client secret, or create one, at: https://admin.10centuries.org/apps/
    init(session: URLSession, clientGUID: String = TenCenturiesSessionManager.appClientGUID, user account: String? = nil) {
        self.session = session
        self.clientGUID = clientGUID
        user = TenCenturiesSessionManager.load(account: account)
    }

    func destroySession() {
        guard let user = user else { return }

        print("AUTH: WARNING: Destroying session for account=«\(user.account)»")
        Keychain.delete(account: user.account, service: "10Centuries")

        let userWithoutPassword = User(account: user.account, token: "")
        self.user = userWithoutPassword
    }

    struct User {
        /// Confusingly, this is actually an email address. But it might not always be!
        let account: String
        let token: String
    }
}


// MARK: - Authenticates requests
extension TenCenturiesSessionManager: RequestAuthenticator {
    var canAuthenticate: Bool {
        return user?.token != nil
    }

    func authenticate(request unauthenticated: URLRequest) -> URLRequest {
        guard let token = user?.token else { return unauthenticated }

        var authenticated = unauthenticated
        authenticated.addValue(token, forHTTPHeaderField: "Authorization")
        return authenticated
    }
}


// MARK: - Persists session info to keychain
extension TenCenturiesSessionManager {
    func save(user: User) {
        TenCenturiesSessionManager.updateLastAccount(user.account)
        guard let tokenData = user.token.data(using: .utf8) else {
            print("AUTH: ERROR: Failed to serialize token as data")
            return
        }

        guard Keychain.add(
            account: user.account,
            service: "10Centuries",
            data: tokenData) else {
            return print("AUTH: ERROR: Failed to save token for \(user.account)")
        }
        print("AUTH: INFO: Successfully saved token for \(user.account)")
    }

    /// Nil account means "use the last one we used".
    static func load(account: String?) -> User? {
        guard let account = account ?? lastAccount else {
            print("AUTH: ERROR: No account to look up token for")
            return nil
        }
        guard let data = Keychain.find(account: account, service: "10Centuries") else {
            print("AUTH: INFO: No login info found for account \(account).")
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
        UserDefaults.standard.set(name, forKey: "lastAccount")
    }

    static func clearLastAccount() {
        print("AUTH: INFO: Last used account cleared")
        UserDefaults.standard.removeObject(forKey: "lastAccount")
    }
}


// MARK: - Handle log in/out actions
extension TenCenturiesSessionManager: SessionManager, TenCenturiesService {
    var loggedInAccountName: String? {
        return user?.account
    }

    var authenticator: RequestAuthenticator { return self }

    func logOut() {
        var request = URLRequest(url: URL(string: "/api/auth/logout", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        /*
         If you're already logged out, you'll see:

         API: DEBUG: Optional(https://api.10centuries.org/auth/logout): Extracted response body: success(["meta": {
                code = 403;
                more = 0;
            }, "data": Invalid Authentication Supplied])


         If you're still logged in, then:

        API: DEBUG: Optional(https://api.10centuries.org/auth/logout): Extracted response body: success(["meta": {
                code = 200;
                server = "28.114";
            }, "data": {
                account = 0;
                "is_active" = 0;
                "updated_at" = "2017-02-10T05:33:20Z";
                "updated_unix" = 1486704800;
            }])
         */
        let _ = send(request: request) { _ in }
        TenCenturiesSessionManager.clearLastAccount()
        user = nil
    }

    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void) {
        var request = URLRequest(url: URL(string: "/api/auth/login", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        let niceDotSocialClientGuid = "7677e4c0-545e-11e8-99a0-54ee758049c3"
        request.attachURLEncodedFormData([
            // 10Cv5 only has one client so far. And anyone can yank the GUID out of the Nice.social page.
            URLQueryItem(name: "client_guid", value: niceDotSocialClientGuid),
            URLQueryItem(name: "account_name", value: account),
            URLQueryItem(name: "account_pass", value: password),
            URLQueryItem(name: "channel_guid", value: "889ab024-90a8-11e8-bbd7-54ee758049c3")
            ])
        let _ = send(request: request) { (result) in
            let result = Result.of { () -> Bool in
                let parent = try result.unwrap()
                let body: [String: Any] = try unpack(parent, "data")
                let token: String = try unpack(body, "token")
                let user = User(account: account, token: token)
                self.user = user
                self.save(user: user)
                return true
            }
            completion(result)
        }
    }

    func destroySessionIfExpired(completion: @escaping (AuthenticatedAccount?) -> Void) {
        guard canAuthenticate else {
            return completion(nil)
        }

        var request = URLRequest(url: URL(string: "/api/auth/status", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "GET"
        let _ = send(request: request) { (result) in
            switch (result) {
            case let .failure(error):
                print("DEBUG: /api/auth/status responded with an error:", error)
                if let error = error as? TenCenturiesError, case let .api(_, text, _) = error {
                    // There aren't any error codes, just strings. But we don't want to sign someone out accidentally.
                    if text == "Invalid or Expired Token Supplied" {
                        self.destroySession()
                    }
                    // otherwise, we'll be able to try again later.
                }
                return completion(nil)

            case let .success(jsonDictionary):
                print("DEBUG: /api/auth/status completed successfully. We must still be logged-in!")
                let account = self.parseAccountFromAuthStatusResponse(jsonDictionary)
                return completion(account)
            }
        }
    }

    func parseAccountFromAuthStatusResponse(_ jsonDictionary: JSONDictionary) -> AuthenticatedAccount {
        // We need access to the personas to star posts at least, so we do ultimately need to parse this.
        var account: AuthenticatedAccount?
        do {
            account = try (jsonDictionary["data"] as? JSONDictionary).map { try parseAuthenticatedAccount(from: $0) }
            print("LOGIN: INFO: Logged in as account=\(String(describing: account))")
        } catch {
            print("LOGIN: ERROR: Failed to parse JSON \"data\" field as AuthenticatedAccount: error=\(error)")
            account = nil
        }

        guard let nonNullAccount = account else {
            print("ERROR: Proceeding with fake account that cannot star posts after failing to parse current account from auth status response=\(jsonDictionary)")
            return AuthenticatedAccount.makeFake()
        }
        return nonNullAccount
    }

    func parseAuthenticatedAccount(from dict: JSONDictionary) throws -> AuthenticatedAccount {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        let account = try JSONDecoder().decode(AuthenticatedAccount.self, from: data)
        return account
    }
}
