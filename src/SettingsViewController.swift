import UIKit

protocol Authenticator {
    var loggedInAccountName: String? { get }

    func logOut()
    func logIn(account: String, password: String, completion: @escaping (Result<Bool>) -> Void)
}

class SettingsViewController: UITableViewController {
    var authenticator: Authenticator?
    func configure(authenticator: Authenticator) {
        self.authenticator = authenticator
    }

    var account: String? { return authenticator?.loggedInAccountName }

    // MARK: - Populates a Table View
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return account == nil ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let account = self.account {
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "KeyValueCell", for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Account", comment: "row title")
                cell.detailTextLabel?.text = account
                return cell

            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
                // swiftlint:disable:previous force_cast
                cell.configure(text: NSLocalizedString("Log Out", comment: "button title"))
                cell.textLabel?.textColor = UIColor.red
                return cell
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
            // swiftlint:disable:previous force_cast
            cell.configure(text: NSLocalizedString("Log In", comment: "button title"))
            return cell
        }
    }

    // MARK: - Allows to log in/out
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let _ = self.account {
            guard 1 == indexPath.row else {
                return
            }

            confirmLogOut()
        } else {
            logIn()
        }
    }

    func confirmLogOut() {
        let alert = UIAlertController(title: NSLocalizedString("Log Out", comment: "title"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Log Out!", comment: "button"), style: .destructive, handler: { [weak self] _ in
            self?.authenticator?.logOut()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "button"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func logIn() {
        performSegue(withIdentifier: "LogIn", sender: self)
    }
}
