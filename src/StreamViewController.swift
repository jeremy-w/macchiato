import UIKit
import SafariServices

class StreamViewController: UITableViewController {
    var stream: Stream?
    var postRepository: PostRepository?
    func configure(stream: Stream, postRepository: PostRepository) {
        self.stream = stream
        self.postRepository = postRepository
        title = stream.name
        tableView?.reloadData()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
    }

    @IBOutlet var newPostButton: UIBarButtonItem?
    override func viewDidLoad() {
        super.viewDidLoad()
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

    // (jws/2016-10-14)TODO: We need access to this.
    // Probably by way of whatever allows us to interact with posts when logged in.
    var isLoggedIn: Bool {
        return true
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
            if let stream = stream {
                stream.posts = posts
                stream.lastFetched = date

                let earliestInBatch = posts.map({ $0.updated }).min()
                switch (stream.earliestFetched, earliestInBatch) {
                case let (was?, now?):
                    stream.earliestFetched = min(was, now)

                case let (nil, now?):
                    stream.earliestFetched = now

                default:
                    break
                }
            }
            tableView?.reloadData()
        } catch {
            print("\(self): ERROR: \(error)")
            if case let TenCenturiesError.api(code: _, text: text, comment: _) = error {
                let alert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: nil, style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
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
        print("LOAD OLDER POSTS!")
    }


    // MARK: - Loads thread on swipe to left
    func prepareToShowThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == "ShowThread" else { return false }
        guard let swipe = sender as? UISwipeGestureRecognizer
        , let post = post(at: swipe.location(in: view)) else { return true }

        guard let streamVC = segue.destination as? StreamViewController
        , let postRepository = self.postRepository else { return true }

        // (jws/2016-10-14)FIXME: Should bootstrap the thread stream with all the posts we already have
        // (match on thread.root)
        streamVC.configure(stream: post.threadStream, postRepository: postRepository)
        return true
    }

    func post(at point: CGPoint) -> Post? {
        guard let index = tableView.indexPathForRow(at: point)?.row else { return nil }
        guard let posts = stream?.posts, posts.isValid(index: index) else { return nil }
        return posts[index]
    }


    // MARK: - Allows to post a new post
    func canSendPostDidChange() {
        navigationItem.rightBarButtonItem = isLoggedIn ? newPostButton : nil
    }

    enum Segue: String {
        case createNewThread = "CreateNewThread"
    }
    func prepareToCreateNewThread(segue: UIStoryboardSegue, sender: Any?) -> Bool {
        guard segue.identifier == Segue.createNewThread.rawValue else { return false }
        guard let composer = segue.destination as? ComposePostViewController else { return true }

        let action: ComposePostViewController.Action
        if let actionSender = sender as? ComposePostViewController.Action {
            action = actionSender
        } else {
            action = .newThread
        }

        guard let postRepository = self.postRepository else { return true }
        composer.configure(postRepository: postRepository, action: action)
        return true
    }

    @IBAction func unwindToParentStreamViewController(_ segue: UIStoryboardSegue) {
        return
    }


    // MARK: - Allows taking actions on posts
    @IBAction func longPressAction(sender: UILongPressGestureRecognizer) {
        guard let target = post(at: sender.location(in: view)) else { return }

        let alert = makePostActionAlert(for: target)
        present(alert, animated: true, completion: nil)
    }

    func makePostActionAlert(for post: Post) -> UIAlertController {
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
                : NSLocalizedString("Edit Pin", comment: "button"), .pin),
            (NSLocalizedString("Repost", comment: "button"), .repost),
            (NSLocalizedString("View in WebView", comment: "button"), .webView),
        ] as [(String, PostAction)] {
            alert.addAction(UIAlertAction(title: title, style: .default, handler: perform(action)))
        }
        let cancel = makeCancelAction()
        alert.addAction(cancel)
        alert.preferredAction = cancel
        return alert
    }

    func makeCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: "button"), style: .default, handler: nil)
    }

    func take(action: PostAction, on post: Post) {
        switch action {
        case .reply:
            performSegue(withIdentifier: Segue.createNewThread.rawValue, sender: ComposePostViewController.Action.newReply(to: post))

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

        case .pin:
            let followup = makePinAlert(for: post)
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

    func makePinAlert(for post: Post) -> UIAlertController {
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
        case pin
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
