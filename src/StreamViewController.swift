import UIKit
import SafariServices

class StreamViewController: UITableViewController {
    var stream: Stream?
    var postRepository: PostRepository?

    var currentUser: Account? {
        didSet {
            canSendPostDidChange()
        }
    }
    func configure(stream: Stream, postRepository: PostRepository, currentUser: Account?) {
        self.stream = stream
        self.postRepository = postRepository
        self.currentUser = currentUser

        title = stream.name

        tableView?.reloadData()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
    }

    @IBOutlet var newPostButton: UIBarButtonItem?
    override func viewDidLoad() {
        super.viewDidLoad()
        canSendPostDidChange()
        refreshControl = makeRefreshControl()
        if let stream = stream, stream.lastFetched == nil {
            refreshAction()
        }
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
        return currentUser != nil
    }


    // MARK: - Supports Pull to Refresh
    @IBAction func refreshAction() {
        guard let stream = stream, let postRepository = postRepository else { return }

        refreshControl?.beginRefreshing()
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
            tableView?.reloadData()
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
        cell.configure(post: post)
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
                let format = NSLocalizedString("Loaded %ld older posts", comment: "accessibility announcement")
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, String(format: format, locale: nil, posts.count))
                self.tableView.reloadData()
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


    // MARK: - Loads thread on swipe to left
    func prepareToShowThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == "ShowThread" else { return false }

        guard let swipe = sender as? UISwipeGestureRecognizer
        , let post = post(at: swipe.location(in: view)) else {
            print("STREAMVC/", stream?.view as Any, ": ERROR: No post at swipe location. Unable to show thread.")
            return true
        }

        guard let streamVC = segue.destination as? StreamViewController
        , let postRepository = self.postRepository else {
            print("STREAMVC/", stream?.view as Any, ": ERROR: Seguing to not-a-streamvc", segue.destination,
                  "or missing our post repository", self.postRepository as Any, "- Unable to show thread.")
            return true
        }

        // (jws/2016-10-14)FIXME: Should bootstrap the thread stream with all the posts we already have
        // (match on thread.root)
        let threadStream = post.threadStream
        print("STREAMVC/", stream?.view as Any, ": INFO: Preparing to show thread stream:", threadStream)
        streamVC.configure(stream: threadStream, postRepository: postRepository, currentUser: currentUser)
        return true
    }

    func post(at point: CGPoint) -> Post? {
        guard let index = tableView.indexPathForRow(at: point)?.row else { return nil }
        guard let posts = stream?.posts, posts.isValid(index: index) else { return nil }
        return posts[index]
    }


    // MARK: - Allows to post a new post
    func canSendPostDidChange() {
        let canSendPost = isLoggedIn
        navigationItem.setRightBarButton(canSendPost ? newPostButton : nil, animated: true)
        print("STREAMVC/", stream?.view as Any, ": DEBUG: Can send post did change:", canSendPost)
    }

    enum Segue: String {
        case createNewThread = "CreateNewThread"
    }
    func prepareToCreateNewThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == Segue.createNewThread.rawValue else { return false }
        guard let composer = segue.destination as? ComposePostViewController else { return true }
        guard let author = currentUser else {
            print("STREAMVC", stream?.view as Any, ": ERROR: No current user - refusing to compose post.")
            return true
        }

        let action = (sender as? ComposePostAction) ?? .newThread

        guard let postRepository = self.postRepository else { return true }
        composer.configure(postRepository: postRepository, action: action, author: author)
        return true
    }

    @IBAction func unwindToParentStreamViewController(_ segue: UIStoryboardSegue) {
        return
    }


    // MARK: - Allows taking actions on posts
    @IBAction func longPressAction(sender: UILongPressGestureRecognizer) {
        let point = sender.location(in: view)
        guard let target = post(at: point) else {
            print("STREAMVC/", stream?.view as Any, ": ERROR: No post at long-press location. Unable to find context to show post actions.")
            return
        }

        let alert = makePostActionAlert(for: target, at: point)
        print("STREAMVC/", stream?.view as Any, ": INFO: Showing alert with", alert.actions.count, "actions for post:", target.id)
        present(alert, animated: true, completion: nil)
    }

    func makePostActionAlert(for post: Post, at point: CGPoint) -> UIAlertController {
        let alert = UIAlertController(title: NSLocalizedString("Post Actions", comment: "alert title"), message: nil, preferredStyle: .actionSheet)
        func perform(_ action: PostAction) -> (UIAlertAction) -> Void {
            return { [weak self] _ in self?.take(action: action, on: post) }
        }
        for (title, action) in [
            (NSLocalizedString("Reply", comment: "button"), .reply),
            (post.you.starred
                ? NSLocalizedString("Unstar", comment: "button")
                : NSLocalizedString("Star", comment: "button"), .star),
            (post.you.pinned == nil
                ? NSLocalizedString("Pin", comment: "button")
                : NSLocalizedString("Edit Pin", comment: "button"), .pin(at: point)),
            (NSLocalizedString("Repost", comment: "button"), .repost),
            (NSLocalizedString("View in WebView", comment: "button"), .webView),
        ] as [(String, PostAction)] {
            switch action {
            case .webView:
                break

            default:
                guard currentUser != nil else { continue }
            }

            alert.addAction(UIAlertAction(title: title, style: .default, handler: perform(action)))
        }

        let cancel = makeCancelAction()
        alert.addAction(cancel)
        alert.preferredAction = cancel
        addPopoverLocationInfo(to: alert, at: point)
        return alert
    }

    func addPopoverLocationInfo(to alert: UIAlertController, at point: CGPoint) {
        guard let presenter = alert.popoverPresentationController
        , let tableView = tableView
        else {
            print("STREAMVC/", stream?.view as Any, ": WARNING: Unable to provide location info for popover: TableView is not loaded.")
            return
        }

        presenter.sourceView = tableView
        presenter.sourceRect = CGRect(origin: point, size: CGSize.zero)
    }

    func makeCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: "button"), style: .default, handler: nil)
    }

    func take(action: PostAction, on post: Post) {
        print("STREAMVC/", stream?.view as Any, ": INFO: Taking post action", action, "on post:", post.id)
        switch action {
        case .reply:
            performSegue(withIdentifier: Segue.createNewThread.rawValue, sender: ComposePostAction.newReply(to: post))

        case .star:
            postRepository?.star(post: post) { result in
                do {
                    let _ = try result.unwrap()
                    guard let stream = self.stream
                    , let index = stream.posts.index(where: { $0.id == post.id }) else { return }
                    DispatchQueue.main.async {
                        stream.posts[index].you.starred = !stream.posts[index].you.starred
                        self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        toast(title: NSLocalizedString("Starred!", comment: "title"))
                    }
                } catch {
                    toast(error: error, prefix: NSLocalizedString("Starring Failed", comment: "title"))
                }
            }

        case let .pin(point):
            let followup = makePinAlert(for: post, at: point)
            present(followup, animated: true, completion: nil)

        case .repost:
            postRepository?.repost(post: post, completion: { (result) in
                guard let stream = self.stream
                , let index = stream.posts.index(where: { $0.id == post.id }) else { return }

                do {
                    let _ = try result.unwrap()
                    DispatchQueue.main.async {
                        stream.posts[index].you.reposted = true
                        self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        toast(title: NSLocalizedString("Reposted!", comment: "title"))
                    }
                } catch {
                    toast(error: error, prefix: NSLocalizedString("Repost Failed", comment: "title"))
                }
            })

        case .webView:
            let webView = SFSafariViewController(url: URL(string: "https://10centuries.org/post/\(post.id)")!)
            present(webView, animated: true, completion: nil)
        }
    }

    func makePinAlert(for post: Post, at point: CGPoint) -> UIAlertController {
        let alert = UIAlertController(title: NSLocalizedString("Pin With…", comment: "button"), message: nil, preferredStyle: .actionSheet)
        for color: Post.PinColor in [.black, .blue, .green, .orange, .yellow, .red] {
            alert.addAction(
                UIAlertAction(
                    title: String(describing: color).capitalized,
                    style: .default,
                    handler: { _ in self.pin(post: post, with: color) }))
        }

        if post.you.pinned != nil {
            alert.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Unpin", comment: "button"),
                    style: .destructive,
                    handler: { _ in self.pin(post: post, with: nil) }))
        }

        let cancel = makeCancelAction()
        alert.addAction(cancel)
        alert.preferredAction = cancel
        addPopoverLocationInfo(to: alert, at: point)
        return alert
    }

    func pin(post: Post, with color: Post.PinColor?) {
        guard let repo = self.postRepository else { return }
        repo.pin(post: post, color: color) { (result) in
            do {
                let posts = try result.unwrap()
                guard let post = posts.first, let stream = self.stream else { return }
                guard let index = stream.posts.index(where: { $0.id == post.id }) else { return }
                DispatchQueue.main.async {
                    stream.posts[index] = post
                    self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                    toast(title: NSLocalizedString("Pinned!", comment: "title"))
                }
            } catch {
                toast(error: error, prefix: NSLocalizedString("Pin Failed", comment: "title"))
            }
        }
    }

    enum PostAction {
        case reply
        case star
        case pin(at: CGPoint)
        case repost
        case webView
    }
}


func toast(error: Error, prefix: String) {
    if case let TenCenturiesError.api(code: _, text: text, comment: _) = error {
        toast(title: "\(prefix): \(text)")
    } else {
        toast(title: "\(prefix): \(error)")
    }
}
