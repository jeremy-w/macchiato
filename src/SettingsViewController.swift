import UIKit

class SettingsViewController: UITableViewController {
    var sessionManager: SessionManager?
    func configure(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    var account: String? { return sessionManager?.loggedInAccountName }

    // MARK: - Populates a Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    let debugInfo = [
        NSLocalizedString("Version", comment: "row title"):
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "—",
        NSLocalizedString("Build", comment: "row title"):
            Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "—",
        NSLocalizedString("Built On", comment: "row title"):
            Bundle.main.object(forInfoDictionaryKey: "BuildDate") ?? "—",
        ].sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })

    enum Section: Int {
        case account
        case info
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNumber: Int) -> Int {
        guard let section = Section(rawValue: sectionNumber) else { return 0 }

        switch section {
        case .account:
            return account == nil ? 1 : 2

        case .info:
            return debugInfo.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNumber: Int) -> String? {
        guard let section = Section(rawValue: sectionNumber) else { return nil }

        switch section {
        case .account:
            return NSLocalizedString("Account", comment: "section title")

        case .info:
            return NSLocalizedString("App Info", comment: "section title")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            print("Settings: ERROR: Bogus index path: \(indexPath)")
            return UITableViewCell()
        }

        switch section {
        case .account:
            return accountCell(forRowAt: indexPath, in: tableView)

        case .info:
            return infoCell(forRowAt: indexPath, in: tableView)
        }
    }

    func accountCell(forRowAt indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        guard let account = account else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
            // swiftlint:disable:previous force_cast
            cell.configure(text: NSLocalizedString("Log In", comment: "button title"))
            return cell
        }

        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "KeyValueCell", for: indexPath)
            cell.textLabel?.text = NSLocalizedString("Account", comment: "row title")
            cell.detailTextLabel?.text = account
            cell.selectionStyle = .none
            return cell

        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.identifier, for: indexPath) as! ButtonCell
            // swiftlint:disable:previous force_cast
            cell.configure(text: NSLocalizedString("Log Out", comment: "button title"))
            cell.textLabel?.textColor = UIColor.red
            return cell
        }
    }

    func infoCell(forRowAt indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "KeyValueCell", for: indexPath)
        cell.textLabel?.text = debugInfo[indexPath.row].key
        cell.detailTextLabel?.text = String(describing: debugInfo[indexPath.row].value)
        cell.selectionStyle = .none
        return cell
    }

    // MARK: - Allows to log in/out
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .account:
            if let _ = self.account {
                guard 1 == indexPath.row else {
                    return
                }

                confirmLogOut()
            } else {
                logIn()
            }
            return

        case .info:
            return
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
        sessionManager.logIn(account: account, password: password) { [weak self] (result) in
            self?.didLogIn(as: account, result: result)
        }
    }

    func didLogIn(as account: String, result: Result<Bool>) {
        do {
            let success = try result.unwrap()
            if success {
                toastSuccessfulLogin(as: account)
            } else {
                toastFailedLogin(error: nil)
            }
        } catch {
            toastFailedLogin(error: error)
        }
        tableView?.reloadData()
    }

    private func toastSuccessfulLogin(as account: String) {
        let format = NSLocalizedString("Logged In As: %@", comment: "toast")
        toast(title: String(format: format, account))
    }

    private func toastFailedLogin(error: Error?) {
        guard let error = error else {
            return toast(title: NSLocalizedString("Log In Failed!", comment: "toast"))
        }

        let format = NSLocalizedString("Log In Failed: %@", comment: "toast")
        let body = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
        toast(title: String(format: format, body))
    }
}
