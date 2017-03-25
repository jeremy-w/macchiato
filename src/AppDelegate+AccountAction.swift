import UIKit

extension AppDelegate {
    func run(_ action: AccountAction, for sender: UIViewController) {
        let accounts = services.accountRepository
        let channel = "ACCOUNTACTION/\(action):"
        print(channel, "INFO: Beginning action")

        switch action {
        case let .toggleFollowing(account: account, currently: currently):
            if currently {
                accounts.unfollow(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                })
            } else {
                accounts.follow(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                })
            }
            break

        case let .toggleMuting(account: account, currently: currently):
            break

        case let .toggleSilencing(account: account, currently: currently):
            break


        case let .viewPosts(from: account):
            break

        case let .viewStars(by: account):
            break

        case let .viewAccountsFollowing(account: account):
            break

        case let .viewAccountsFollowed(by: account):
            break
        }
    }
}
