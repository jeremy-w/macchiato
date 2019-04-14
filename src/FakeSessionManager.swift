class FakeSessionManager: SessionManager {
    var loggedInAccountName: String?

    func logOut() {
        loggedInAccountName = nil
    }

    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void) {
        loggedInAccountName = account
        completion(.success(true))
    }

    init(loggedInAs email: String? = nil) {
        loggedInAccountName = email
    }

    func destroySessionIfExpired(completion: @escaping (Bool) -> Void) {
        guard loggedInAccountName != nil else {
            return completion(false)
        }

        loggedInAccountName = nil
        completion(true)
    }
}
