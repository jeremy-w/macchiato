protocol SessionManager: class {
    var loggedInAccountName: String? { get }

    func logOut()
    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void)
}


import Foundation

extension Notification.Name {
    /// Notification object is the broadcasting SessionManager.
    static let loggedInAccountDidChange = Notification.Name("LoggedInAccountDidChangeNotification")
}
