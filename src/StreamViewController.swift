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
    func prepareToShowThread(segue: UIStoryboardSegue, sender: Any) -> Bool {
        guard segue.identifier == "ShowThread" else { return false }
        guard let swipe = sender as? UISwipeGestureRecognizer
        , let post = post(at: swipe.location(in: view)) else { return true }

        guard let streamVC = segue.destination as? StreamViewController
        , let postRepository = self.postRepository else { return true }

        // (jws/2016-10-14)FIXME: Should create the stream ourselves, and bootstrap with all the posts we already have in the thread (filter by thread.root match)
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

    @IBAction func unwindToParentStreamViewController(_ segue: UIStoryboardSegue) {
        return
    }
}
