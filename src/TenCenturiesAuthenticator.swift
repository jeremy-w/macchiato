import Foundation

class TenCenturiesAuthenticator {
    let session: URLSession
    let client: UUID
    let user: User?
    init(session: URLSession, client: UUID, user: String? = nil) {
        self.session = session
        self.client = client
        self.user = TenCenturiesAuthenticator.load(account: user, client: client)
    }

    func save(user: User) {
        TenCenturiesAuthenticator.updateLastAccount(user.account)
        // (@jeremy-w/2016-10-09)TODO: Finish implementing auth.
    }

    /// Nil account means "use the last one we used".
    static func load(account: String?, client: UUID) -> User? {
        // (@jeremy-w/2016-10-09)TODO: Finish implementing auth.
        return nil
    }

    static var lastAccount: String? {
        // (@jeremy-w/2016-10-09)TODO: Finish implementing auth.
        return "me@jeremywsherman.com"
    }

    static func updateLastAccount(_ name: String) {
        // (@jeremy-w/2016-10-09)TODO: Finish implementing auth.
    }

    struct User {
        let account: String
        let token: String
    }
}

extension TenCenturiesAuthenticator: Authenticator {
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

extension TenCenturiesAuthenticator: TenCenturiesService {
}
