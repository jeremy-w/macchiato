protocol SessionManager: class {
    var loggedInAccountName: String? { get }

    func logOut()
    /// Resolves to `true` if log-in was successful.
    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void)

    /// Resolves to an account if we still have a session.
    func destroySessionIfExpired(completion: @escaping (Account?) -> Void)
}


import Foundation

extension Notification.Name {
    /// Notification object is the broadcasting SessionManager.
    static let loggedInAccountDidChange = Notification.Name("LoggedInAccountDidChangeNotification")
}
