import UIKit

class StreamViewController: UITableViewController {
    var stream: Stream?
    var postRepository: PostRepository?

    private var identityChangeListener: Any?
    private(set) var identity = Identity() {
        didSet {
            canSendPostDidChange()
            identityChangeListener = NotificationCenter.default.addObserver(
                forName: .identityDidChange, object: identity, queue: OperationQueue.main,
                using: { [weak self] _ in
                    self?.canSendPostDidChange()
            })
        }
    }

    func configure(stream: Stream, postRepository: PostRepository, identity: Identity) {
        print("configured:", self)
        self.stream = stream
        self.postRepository = postRepository
        self.identity = identity

        title = stream.name

        guard isViewLoaded, let tableView = tableView else { return }
        tableView.reloadData()
    }

    @IBOutlet var newPostButton: UIBarButtonItem?
    override func viewDidLoad() {
        print("view loaded:", self)
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 350

        canSendPostDidChange()
        refreshControl = makeRefreshControl()
        if let stream = stream, stream.lastFetched == nil {
            refreshAction()
        }

        makeNewPostButtonAccessible()
    }

    func makeNewPostButtonAccessible() {
        guard let newPostButton = newPostButton else { return }

        newPostButton.accessibilityLabel = NSLocalizedString("New Post", comment: "accessibility label")
        newPostButton.accessibilityHint = NSLocalizedString("Write a new post", comment: "accessibility hint")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if prepareToShowThread(segue: segue, sender: sender) { return }
        if prepareToCreateNewThread(segue: segue, sender: sender) { return }
    }

    override func viewWillAppear(_ animated: Bool) {
        canSendPostDidChange()
    }

    var isLoggedIn: Bool {
        // (jeremy-w/2019-04-18)FIXME: As long as we have valid auth token, we can post. Even if we can't fetch Account.
        // This is why my "Account.makeFake()" as identity.account hack works so well.
        return identity.account != nil
    }


    // MARK: - Supports Pull to Refresh
    @IBAction func refreshAction() {
        guard let stream = stream, let postRepository = postRepository else { return }

        refreshControl?.beginRefreshing()

        if isViewLoaded, !view.isHidden, view.window != nil {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: NSLocalizedString("Loading posts", comment: "accessibility announcement"))
        }

        postRepository.find(stream: stream, options: []) {
            [weak self] (result: Result<[Post]>) -> Void in
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
                self?.didReceivePosts(result: result, at: Date())
            }
        }
    }

    func didReceivePosts(result: Result<[Post]>, at date: Date) {
        do {
            let posts = try result.unwrap()
            stream?.replacePosts(with: posts, fetchedAt: date)

            guard isViewLoaded, let tableView = tableView else { return }
            if !view.isHidden, view.window != nil {
                let format = NSLocalizedString("Loaded %ld posts", comment: "accessibility announcement")
                UIAccessibility.post(
                    notification: .layoutChanged,
                    argument: String.localizedStringWithFormat(format, posts.count))
            }
            tableView.reloadData()
        } catch {
            reportError(error)
        }
    }

    func makeRefreshControl() -> UIRefreshControl {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
        return control
    }


    // MARK: - Vends posts to a table view
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (stream?.posts.count ?? 0) + 1 /* Load Older */
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let stream = stream, stream.posts.isValid(index: indexPath.row) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadOlderButton", for: indexPath)
            cell.accessibilityTraits.insert(.button)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.identifier, for: indexPath) as! PostCell
        // swiftlint:disable:previous force_cast
        let post = stream.posts[indexPath.row]
        let display = post.originalPost ?? post
        cell.configure(post: display, headerView: header(for: post), delegate: self)
        return cell
    }

    func header(for post: Post) -> UIView? {
        let isRepost = post.originalPost != nil
        if isRepost {
            return buildRepostBanner(reposter: post.account, repostDate: post.published)
        }

        let isSpecificallyHighlightingPostInteractions = stream?.view == .interactions
        guard isSpecificallyHighlightingPostInteractions else { return nil }

        return labelDescribingInteractionsWithLoggedInUsersPost(post)
    }

    func labelDescribingInteractionsWithLoggedInUsersPost(_ post: Post) -> UILabel? {
        let names = post.stars.map({ $0.userAtName })
        guard !names.isEmpty else { return nil }

        let format = NSLocalizedString("Starred by: %@", comment: "label: %@ is account names")
        let series = names.joined(separator: " ")
        let text = String.localizedStringWithFormat(format, series)

        let label = UILabel()
        label.numberOfLines = 0

        enableAutoContentSizeUpdates(for: label)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let body = bodyFont.fontDescriptor
        let bolded = body.withSymbolicTraits(.traitBold).map({ UIFont(descriptor: $0, size: 0) })
        label.font = bolded ?? bodyFont

        label.text = text
        return label
    }

    func buildRepostBanner(reposter account: Account, repostDate: Date) -> BylineView {
        let repostFormat = NSLocalizedString("Reposted by: @%@", comment: "%@ is username")
        let author = String.localizedStringWithFormat(repostFormat, account.username)

        let banner = BylineView.makeView()
        banner.configure(imageURL: account.avatarURL, author: author, date: repostDate)
        return banner
    }


    // MARK: - Loads older posts when button in last row activated
    @IBAction func loadOlderPostsAction() {
        guard let repo = postRepository, let stream = stream else { return }
        guard let earliest = stream.earliestFetched else {
            return refreshAction()
        }

        UIAccessibility.post(
            notification: .layoutChanged,
            argument: NSLocalizedString("Loading older posts", comment: "accessibility announcement"))
        repo.find(stream: stream, options: [.before(earliest)]) { [weak self] in self?.didReceivePosts(result: $0, olderThan: earliest)
        }
    }

    func didReceivePosts(result: Result<[Post]>, olderThan date: Date) {
        do {
            let posts = try result.unwrap()
            stream?.merge(posts: posts, olderThan: date)
            DispatchQueue.main.async {
                guard self.isViewLoaded, let tableView = self.tableView else { return }

                let format = NSLocalizedString("Loaded %ld older posts", comment: "accessibility announcement")
                UIAccessibility.post(
                    notification: .layoutChanged,
                    argument: String.localizedStringWithFormat(format, posts.count))
                tableView.reloadData()
            }
        } catch {
            reportError(error)
        }
    }

    func reportError(_ error: Error) {
        print("STREAMVC/", stream?.view as Any, ": ERROR: \(error)")
        if case let TenCenturiesError.api(code: _, text: text, comment: _) = error {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "button"), style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }


    // MARK: - Loads thread on swipe to left (or selection when AT enabled)
    func prepareToShowThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == Segue.showThread.rawValue else { return false }

        let selectedPost: Post
        if let swipe = sender as? UISwipeGestureRecognizer {
            guard let post = post(at: swipe.location(in: view)) else {
                print("STREAMVC/", stream?.view as Any, ": ERROR: No post at swipe location. Unable to show thread.")
                return true
            }
            selectedPost = post
        } else if let post = sender as? Post {
            selectedPost = post
        } else {
            guard let tableView = tableView, let selection = tableView.indexPathForSelectedRow else {
                return true
            }
            let rect = tableView.rectForRow(at: selection)
            guard let post = post(at: CGPoint(x: rect.midX, y: rect.midY)) else {
                print("STREAMVC/", stream?.view as Any, ": ERROR: No post at cell location. Unable to show thread.")
                return true
            }
            selectedPost = post
        }

        guard let streamVC = segue.destination as? StreamViewController
        , let postRepository = self.postRepository else {
            print("STREAMVC/", stream?.view as Any, ": ERROR: Seguing to not-a-streamvc", segue.destination,
                  "or missing our post repository", self.postRepository as Any, "- Unable to show thread.")
            return true
        }

        // Bootstrap the thread stream with all the posts we already have (match on thread.root)
        // (jeremy-w/2017-03-05)TODO: Shift this logic onto the Stream itself
        let actionPost = selectedPost.originalPost ?? selectedPost
        let threadStream = actionPost.threadStream
        if let stream = stream {
            let postIDAtRootOfThread = actionPost.thread?.root ?? actionPost.id
            threadStream.posts = stream.posts.filter(
                { $0.id == postIDAtRootOfThread
                    || $0.parentID == postIDAtRootOfThread
                    || $0.thread?.root == postIDAtRootOfThread })
            print("STREAMVC/", stream.view,
                  ": DEBUG: Bootstrapping thread-view with", threadStream.posts.count, "posts matching ID", postIDAtRootOfThread)
        }

        print("STREAMVC/", stream?.view as Any, ": INFO: Preparing to show thread stream:", threadStream)
        streamVC.configure(stream: threadStream, postRepository: postRepository, identity: identity)
        return true
    }

    func post(at point: CGPoint) -> Post? {
        guard let index = tableView.indexPathForRow(at: point)?.row else { return nil }
        guard let posts = stream?.posts, posts.isValid(index: index) else { return nil }
        return posts[index]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning else { return }

        performSegue(withIdentifier: Segue.showThread.rawValue, sender: nil)
    }


    // MARK: - Allows to post a new post
    var newPostKeyCommand = UIKeyCommand(
        input: "n",
        modifierFlags: .command,
        action: #selector(StreamViewController.composePostAction),
        discoverabilityTitle: NSLocalizedString("New Post", comment: "keyboard discoverability title"))

    func canSendPostDidChange() {
        guard isViewLoaded else { return }

        let canSendPost = isLoggedIn
        newPostButton?.isEnabled = canSendPost
        print("STREAMVC/", stream?.view as Any, self, ": DEBUG: Can send post did change:", canSendPost)

        removeKeyCommand(newPostKeyCommand)
        if canSendPost {
            addKeyCommand(newPostKeyCommand)
        }
    }

    /// Required to vend key commands.
    override var canBecomeFirstResponder: Bool {
        return true
    }

    /// Called by `newPostKeyCommand`.
    @IBAction func composePostAction() {
        guard isLoggedIn else { return }

        performSegue(withIdentifier: Segue.createNewThread.rawValue, sender: newPostButton)
    }

    enum Segue: String {
        case showThread = "ShowThread"
        case createNewThread = "CreateNewThread"
    }
    func prepareToCreateNewThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == Segue.createNewThread.rawValue else { return false }
        guard let composer = segue.destination as? ComposePostViewController else { return true }
        guard let author = identity.account else {
            print("STREAMVC", stream?.view as Any, ": ERROR: No current user - refusing to compose post.")
            return true
        }

        let action = (sender as? ComposePostAction) ?? .newThread

        guard let postRepository = self.postRepository else { return true }

        // (jeremy-w/2017-02-23)FIXME: This is such singleton abuse.
        // But piping stuff to the leaves is just exhausting.
        // The overall design needs to move to directly fire out to where the services are,
        // and this is one way to do that.
        //
        // Really, we should be kicking the "spawn this thing" work out to _our_ delegate!
        guard let abomination: ComposePostViewControllerDelegate = UIApplication.shared.delegate as? AppDelegate else { return true }
        composer.configure(delegate: abomination, postRepository: postRepository, action: action, author: author)
        return true
    }

    @IBAction func unwindToParentStreamViewController(_ segue: UIStoryboardSegue) {
        return
    }
}


extension StreamViewController: PostCellDelegate {
    func tapped(link: URL, in cell: PostCell) {
        displayInWebView(link)
    }

    func tapped(image: UIImage?, from url: URL, in cell: PostCell) {
        displayInWebView(url)
    }

    func tapped(actionButton: UIButton, in cell: PostCell) {
        let rect = actionButton.bounds

        let direction: UIUserInterfaceLayoutDirection
        if #available(iOS 10.0, *) {
            direction = actionButton.effectiveUserInterfaceLayoutDirection
        } else {
            direction = UIView.userInterfaceLayoutDirection(for: actionButton.semanticContentAttribute)
        }

        let leadingEdgeCenteredVertically = CGPoint(x: (direction == .leftToRight) ? rect.minX : rect.maxX, y: rect.midY)
        let point = actionButton.convert(leadingEdgeCenteredVertically, to: view)
        presentPostActions(at: point)
    }

    func tappedAvatar(in cell: PostCell) {
        guard let account = cell.post?.account else {
            print("STREAM: WARNING: Tapped cell without a post account; cannot show avatar")
            return
        }

        showAccountView(displaying: account)
    }

    func showAccountView(displaying account: Account) {
        let accountVC = AccountViewController()
        guard let actor = UIApplication.shared.delegate as? AppDelegate else { return }

        accountVC.configure(account: account, actor: {
            [weak accountVC] action in
            guard let accountVC = accountVC else { return }
            actor.run(action, for: accountVC)
        })
        show(accountVC, sender: self)
    }

    func longPressedAvatar(in cell: PostCell) {
        print("TODO: display account actions")
    }
}
