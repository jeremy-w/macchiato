protocol SessionManager {
    var loggedInAccountName: String? { get }

    func logOut()
    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void)
}
