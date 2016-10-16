import UIKit

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
        postRepository.find(stream: stream, since: stream.posts.first) {
            [weak self] (result: Result<[Post]>) -> Void in
            DispatchQueue.main.async {
                self?.refreshControl?.endRefreshing()
                self?.didReceivePosts(result: result)
            }
        }
    }

    func didReceivePosts(result: Result<[Post]>) {
        do {
            stream?.posts = try result.unwrap()
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
        return stream?.posts.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.identifier, for: indexPath) as! PostCell
        // swiftlint:disable:previous force_cast
        if let post = stream?.posts[indexPath.row] {
            cell.configure(post: post)
        }
        return cell
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
        return stream?.posts[index]
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
            (NSLocalizedString("Un/Star", comment: "button"), .star),
            (NSLocalizedString("Un/Pin", comment: "button"), .pin),
        ] as [(String, PostAction)] {
            alert.addAction(UIAlertAction(title: title, style: .default, handler: perform(action)))
        }
        return alert
    }

    func take(action: PostAction, on post: Post) {
        switch action {
        case .reply:
            performSegue(withIdentifier: Segue.createNewThread.rawValue, sender: ComposePostViewController.Action.newReply(to: post))

        case .star:
            postRepository?.star(post: post) { result in
                if case .success = result {
                    guard let stream = self.stream
                    , let index = stream.posts.index(where: { $0.id == post.id }) else { return }

                    stream.posts[index].you.starred = !stream.posts[index].you.starred
                    self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
                /* (jws/2016-10-15)FIXME: Need general "report the error" handler. */
            }

        case .pin:
            /* (jws/2016-10-15)TODO: Ask what color they want. */
            break

        case .repost:
            postRepository?.repost(post: post, completion: { (result) in
                guard let stream = self.stream
                , let index = stream.posts.index(where: { $0.id == post.id }) else { return }

                if case .success = result {
                    stream.posts[index].you.reposted = true
                    self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
            })
        }
    }

    enum PostAction {
        case reply
        case star
        case pin
        case repost
    }
}
