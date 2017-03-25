import UIKit

class AccountViewController: UIViewController {
    private(set) var account: Account?
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


    // MARK: - Edit your relationship with the account
    // (jeremy-w/2017-03-25)FIXME: Follow and such make no sense if you're not logged in. :\
    @IBAction func toggleFollowAction() {
    }

    @IBAction func toggleMuteAction() {
    }

    @IBAction func toggleSilenceAction() {
    }


    // MARK: - Display posts and accounts related to this account
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
        title = (account?.username).map({ "@" + $0 })
        handle?.text = title
        name?.text = account?.fullName
        about?.text = account?.descriptionMarkdown

        let format = NSLocalizedString("Joined: %@", comment: "%@ is date")
        // Full+Long is like: Wednesday, February 22 2017 at 12:00:50 PM EST
        let dateString = (account?.createdAt).map({DateFormatter.localizedString(from: $0, dateStyle: .full, timeStyle: .long)}) ?? ""
        created?.text = String.localizedStringWithFormat(format, dateString)
    }

    func updateRelationshipButtons() {
        guard let account = account else {
            follow?.isHidden = true
            mute?.isHidden = true
            silence?.isHidden = true
            return
        }

        follow?.isHidden = false
        mute?.isHidden = false
        silence?.isHidden = false

        follow?.setTitle(
            account.youFollow
                ? NSLocalizedString("Unfollow", comment: "button label")
                : NSLocalizedString("Follow", comment: "button label"),
            for: .normal)
        mute?.setTitle(
            account.isMuted
                ? NSLocalizedString("Unmute", comment: "button label")
                : NSLocalizedString("Mute", comment: "button label"),
            for: .normal)
        silence?.setTitle(
            account.isSilenced
                ? NSLocalizedString("Unsilence", comment: "button label")
                : NSLocalizedString("Silence", comment: "button label"),
            for: .normal)
    }

    func updateStatisticsLinks() {
        posts?.setTitle(String.localizedStringWithFormat("%d Posts", account?.counts[Account.CountKey.socialposts] ?? -1), for: .normal)
        stars?.setTitle(String.localizedStringWithFormat("%d Stars", account?.counts[Account.CountKey.stars] ?? -1), for: .normal)
        following?.setTitle(String.localizedStringWithFormat("Following %d", account?.counts[Account.CountKey.following] ?? -1), for: .normal)
        followers?.setTitle(String.localizedStringWithFormat("Followed by %d", account?.counts[Account.CountKey.followers] ?? -1), for: .normal)
    }
}
