import UIKit

enum AccountAction {
    case toggleFollowing(account: Account, currently: Bool)
    case toggleMuting(account: Account, currently: Bool)
    case toggleSilencing(account: Account, currently: Bool)

    case viewPosts(from: Account)
    case viewStars(by: Account)
    case viewAccountsFollowing(account: Account)
    case viewAccountsFollowed(by: Account)
}

class AccountViewController: UIViewController {
    private(set) var account: Account?
    private(set) var actor: (AccountAction) -> Void = { _ in }
    func configure(account: Account, actor: @escaping (AccountAction) -> Void) {
        self.account = account
        self.actor = actor
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
        guard let account = account else { return }

        actor(.toggleFollowing(account: account, currently: account.youFollow))
    }

    @IBAction func toggleMuteAction() {
        guard let account = account else { return }

        actor(.toggleMuting(account: account, currently: account.isMuted))
    }

    @IBAction func toggleSilenceAction() {
        guard let account = account else { return }

        actor(.toggleSilencing(account: account, currently: account.isSilenced))
    }


    // MARK: - Display posts and accounts related to this account
    @IBAction func viewPostsAction() {
        guard let account = account else { return }

        actor(.viewPosts(from: account))
    }

    @IBAction func viewStarsAction() {
        guard let account = account else { return }

        actor(.viewStars(by: account))
    }

    @IBAction func viewFollowingAction() {
        guard let account = account else { return }

        actor(.viewAccountsFollowed(by: account))
    }

    @IBAction func viewFollowersAction() {
        guard let account = account else { return }

        actor(.viewAccountsFollowing(account: account))
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
