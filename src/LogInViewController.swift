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

    func updateButtonDisabled() {
        guard let button = logIn else { return }

        let disabled = ((account?.text?.isEmpty ?? true)
            || (password?.text?.isEmpty ?? true))
        button.isEnabled = !disabled
    }
}

extension LogInViewController: UITextFieldDelegate {
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        updateButtonDisabled()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        updateButtonDisabled()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateButtonDisabled()
    }

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
