import UIKit

class AccountViewController: UIViewController {
    var account: Account?
    func configure(account: Account) {
        self.account = account
        updateView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBOutlet var avatar: AvatarImageView?
    @IBOutlet var handle: UILabel?
    @IBOutlet var name: UILabel?
    @IBOutlet var about: UILabel?
    @IBOutlet var created: UILabel?

    @IBOutlet var follow: UIButton?
    @IBOutlet var mute: UIButton?
    @IBOutlet var silence: UIButton?

    @IBOutlet var posts: UIButton?
    @IBOutlet var stars: UIButton?
    @IBOutlet var following: UIButton?
    @IBOutlet var followers: UIButton?

    @IBAction func toggleFollowAction() {
    }

    @IBAction func toggleMuteAction() {
    }

    @IBAction func toggleSilenceAction() {
    }

    @IBAction func viewPostsAction() {
    }

    @IBAction func viewStarsAction() {
    }

    @IBAction func viewFollowingAction() {
    }

    @IBAction func viewFollowersAction() {
    }
}


extension AccountViewController {
    func updateView() {
        guard isViewLoaded else { return }

        displayBasicAccountInfo()
        updateRelationshipButtons()
        updateStatisticsLinks()
    }

    func displayBasicAccountInfo() {
        avatar?.display(account: account, delegate: nil)
        handle?.text = account?.username
        name?.text = account?.fullName
        about?.text = account?.description
        // FIXME: Parse createdAt!
        created?.text = String.localizedStringWithFormat("Joined: %@", "")
    }

    func updateRelationshipButtons() {
        guard let _ = account else {
            follow?.isHidden = true
            mute?.isHidden = true
            silence?.isHidden = true
            return
        }

        follow?.isHidden = false
        mute?.isHidden = false
        silence?.isHidden = false

        // FIXME: Need to parse youFollow etc!
    }

    func updateStatisticsLinks() {
        // FIXME: Not really parsing this, either.
    }
}
