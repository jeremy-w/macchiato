import UIKit

class AccountViewController: UIViewController {
    var account: Account?
    func configure(account: Account) {
        self.account = account
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
