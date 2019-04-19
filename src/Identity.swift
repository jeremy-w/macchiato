import Foundation

extension Notification.Name {
    /**
     Object is the Identity. Userinfo is absent.
     */
    static let identityDidChange = Notification.Name("Macchiato.Identity.AccountDidChange")
}


/**
 Tracks the user's current identity represented by an Account.
 */
class Identity {
    init() {}

    // MARK: - Tracks the current user's account info
    private(set) var account: Account? {
        didSet {
            print("ACCOUNT: INFO: Current user did change to:", account as Any)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .identityDidChange, object: self, userInfo: nil)
            }
        }
    }

    func update(account: Account) {
        self.account = account
    }

    func logOut() {
        account = nil
    }
}
