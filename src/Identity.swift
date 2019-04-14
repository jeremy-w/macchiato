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

    func update(using accountRepository: AccountRepository) {
        // (jeremy-w/2019-04-14)FIXME: This fails unless logged-in.
        // We should teach SessionManager how to check for valid token, then caller can check that.
        // And then TenC repo can check if we have any token at all and preemptively fail without hitting backend.
        accountRepository.account(id: "me") { (result) in
            do {
                self.account = try result.unwrap()
            } catch {
                print("AUTH: ERROR: Failed fetching user account for logged-in user with error:", error)
                // (jeremy-w/2017-01-28)???: Perhaps only clear if we get "Unauthorized"?
                self.account = nil
            }
        }
    }

    func logOut() {
        account = nil
    }
}
