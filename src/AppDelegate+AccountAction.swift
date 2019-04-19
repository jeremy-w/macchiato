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
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Unfollowed @%@ ✂️", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to unfollow @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            } else {
                accounts.follow(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Followed @%@ 🖇", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to follow @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            }

        case let .toggleMuting(account: account, currently: currently):
            if currently {
                accounts.unmute(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Unmuted @%@ 🔊", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to unmute @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            } else {
                accounts.mute(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Muted @%@ 🔇", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to mute @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            }

        case let .toggleSilencing(account: account, currently: currently):
            if currently {
                accounts.unsilence(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Unsilenced @%@ 👂", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to unmute @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            } else {
                accounts.silence(accountWithID: account.id, completion: { (result) in
                    print(channel, "INFO: Result:", result)
                    do {
                        let _ = try result.unwrap()
                        let template = NSLocalizedString("Silenced @%@ 🤐", comment: "toast")
                        let title = String.localizedStringWithFormat(template, account.username)
                        toast(title: title)
                    } catch {
                        let prefix = String.localizedStringWithFormat(NSLocalizedString("Failed to mute @%@", comment: "toast"), account.username)
                        toast(error: error, prefix: prefix)
                    }
                })
            }


        // (jeremy-w/2019-04-13)TODO: Allow viewing an account's posts. Joanna would like this.
        case let .viewPosts(from: account):
            NSLog("TODO: \(#function): .viewPosts of \(account)")
            break

        case let .viewStars(by: account):
            NSLog("TODO: \(#function): .viewStars of \(account)")
            break

        case let .viewAccountsFollowing(account: account):
            NSLog("TODO: \(#function): .viewAccountsFollowing \(account)")
            break

        case let .viewAccountsFollowed(by: account):
            NSLog("TODO: \(#function): .viewAccountsFollowed by \(account)")
            break
        }
    }
}
