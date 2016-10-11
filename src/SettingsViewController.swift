import UIKit

class SettingsViewController: UITableViewController {
    var sessionManager: SessionManager?
    func configure(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    var account: String? { return sessionManager?.loggedInAccountName }

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
            self?.sessionManager?.logOut()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "button"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func logIn() {
        performSegue(withIdentifier: "LogIn", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        guard segue.identifier == "LogIn" else { return }
        guard let target = segue.destination as? LogInViewController else {
            preconditionFailure("expected destinatino to be LogInViewController, found: \(segue.destination)")
        }

        target.configure { [weak self] (item) in
            self?.logInWithCredentials(account: item.0, password: item.1)
        }
    }

    func logInWithCredentials(account: String, password: String) {
        guard let sessionManager = sessionManager else {
            assertionFailure("\(self) was not configured with sessionManager: cannot log in")
            return
        }

        toast(title: NSLocalizedString("Logging In…", comment: "toast"))
        sessionManager.logIn(account: account, password: password, completion: { (result) in
            do {
                let didLogIn = try result.unwrap()
                if didLogIn {
                    let format = NSLocalizedString("Logged In As: %@", comment: "toast")
                    toast(title: String(format: format, account))
                } else {
                    toast(title: NSLocalizedString("Log In Failed!", comment: "toast"))
                }
            } catch {
                let format = NSLocalizedString("Log In Failed: %@", comment: "toast")
                let body = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                toast(title: String(format: format, body))
            }
        })
    }
}
