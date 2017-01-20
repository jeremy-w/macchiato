class FakeSessionManager: SessionManager {
    var loggedInAccountName: String?

    func logOut() {
        loggedInAccountName = nil
    }

    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void) {
        loggedInAccountName = account
        completion(.success(true))
    }
}
