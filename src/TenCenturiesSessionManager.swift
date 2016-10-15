import Foundation
import Security

class TenCenturiesSessionManager {
    let session: URLSession
    let clientGUID: String
    fileprivate(set) var user: User?
    // You will need to define a `static var appClientGUID: String` in the ignored file: TenCenturiesSessionManager+AppClientGUID.swift
    // to provide your client secret to the app.
    // You can find your client secret, or create one, at: https://admin.10centuries.org/apps/
    init(session: URLSession, clientGUID: String = TenCenturiesSessionManager.appClientGUID, user account: String? = nil) {
        self.session = session
        self.clientGUID = clientGUID
        user = TenCenturiesSessionManager.load(account: account)
    }

    struct User {
        let account: String
        let token: String
    }
}


// MARK: - Authenticates requests
extension TenCenturiesSessionManager: RequestAuthenticator {
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
}


// MARK: - Handle log in/out actions
extension TenCenturiesSessionManager: SessionManager, TenCenturiesService {
    var loggedInAccountName: String? {
        return nil
    }

    var authenticator: RequestAuthenticator { return self }

    func logOut() {
        var request = URLRequest(url: URL(string: "/auth/logout", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        let _ = send(request: request) { _ in }
    }

    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void) {
        var request = URLRequest(url: URL(string: "/auth/login", relativeTo: TenCenturies.baseURL)!)
        request.httpMethod = "POST"
        request.attachURLEncodedFormData([
            URLQueryItem(name: "client_guid", value: clientGUID),
            URLQueryItem(name: "acctname", value: account),
            URLQueryItem(name: "acctpass", value: password)
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
}
