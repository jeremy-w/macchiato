import UIKit

class LogInViewController: UIViewController {
    @IBOutlet var account: UITextField?
    @IBOutlet var password: UITextField?
    @IBOutlet var logIn: UIButton?
    var completion: (((account: String, password: String)) -> Void)?

    func configure(completion: @escaping ((account: String, password: String)) -> Void) {
        self.completion = completion
    }

    @IBAction func logInAction() {
        guard let user = account?.text, let pass = password?.text, let delegate = completion else {
            return
        }

        delegate((account: user, password: pass))
    }


    // MARK: - Updates "Log In" enabled when text changes
    func updateButtonDisabled() {
        guard let button = logIn else { return }

        let disabled = ((account?.text?.isEmpty ?? true)
            || (password?.text?.isEmpty ?? true))
        button.isEnabled = !disabled
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateButtonDisabledWhenTextChanges()
    }

    func updateButtonDisabledWhenTextChanges() {
        for textField in [account, password].flatMap({ $0 }) {
            NotificationCenter.default.addObserver(
                self, selector: #selector(updateButtonDisabled),
                name: .UITextFieldTextDidChange, object: textField)
        }
    }
}

extension LogInViewController: UITextFieldDelegate {
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        updateButtonDisabled()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateButtonDisabled()
    }


    // MARK: - Triggers "Log In" action on Return in password field
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        updateButtonDisabled()
        treatAsLogInButtonPressIfFormFinished(with: textField)
        return true
    }

    func treatAsLogInButtonPressIfFormFinished(with textField: UITextField) {
        guard let button = logIn else { return }

        if textField == password && button.isEnabled {
            button.sendActions(for: .touchUpInside)
        }
    }
}
