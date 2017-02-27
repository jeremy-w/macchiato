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

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44

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
        return identity.account != nil
    }


    // MARK: - Supports Pull to Refresh
    @IBAction func refreshAction() {
        guard let stream = stream, let postRepository = postRepository else { return }

        refreshControl?.beginRefreshing()

        if isViewLoaded, !view.isHidden, view.window != nil {
            UIAccessibilityPostNotification(
                UIAccessibilityLayoutChangedNotification,
                NSLocalizedString("Loading posts", comment: "accessibility announcement"))
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
                UIAccessibilityPostNotification(
                    UIAccessibilityLayoutChangedNotification,
                    String.localizedStringWithFormat(format, posts.count))
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
            cell.accessibilityTraits |= UIAccessibilityTraitButton
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.identifier, for: indexPath) as! PostCell
        // swiftlint:disable:previous force_cast
        let post = stream.posts[indexPath.row]
        cell.configure(post: post, delegate: self)
        return cell
    }


    // MARK: - Loads older posts when button in last row activated
    @IBAction func loadOlderPostsAction() {
        guard let repo = postRepository, let stream = stream else { return }
        guard let earliest = stream.earliestFetched else {
            return refreshAction()
        }

        UIAccessibilityPostNotification(
            UIAccessibilityLayoutChangedNotification,
            NSLocalizedString("Loading older posts", comment: "accessibility announcement"))
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
                UIAccessibilityPostNotification(
                    UIAccessibilityLayoutChangedNotification,
                    String.localizedStringWithFormat(format, posts.count))
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
                alert.addAction(UIAlertAction(title: nil, style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }


    // MARK: - Loads thread on swipe to left (or selection when AT enabled)
    func prepareToShowThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == "ShowThread" else { return false }

        let selectedPost: Post
        if let swipe = sender as? UISwipeGestureRecognizer {
            guard let post = post(at: swipe.location(in: view)) else {
                print("STREAMVC/", stream?.view as Any, ": ERROR: No post at swipe location. Unable to show thread.")
                return true
            }
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

        // (jws/2016-10-14)FIXME: Should bootstrap the thread stream with all the posts we already have
        // (match on thread.root)
        let threadStream = selectedPost.threadStream
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
        guard UIAccessibilityIsVoiceOverRunning() || UIAccessibilityIsSwitchControlRunning() else { return }

        performSegue(withIdentifier: "ShowThread", sender: nil)
    }


    // MARK: - Allows to post a new post
    func canSendPostDidChange() {
        guard isViewLoaded else { return }

        let canSendPost = isLoggedIn
        newPostButton?.isEnabled = canSendPost
        print("STREAMVC/", stream?.view as Any, self, ": DEBUG: Can send post did change:", canSendPost)
    }

    enum Segue: String {
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
        guard let abomination = UIApplication.shared.delegate as? AppDelegate else { return true }
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
}
