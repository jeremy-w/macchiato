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

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = makeRefreshControl()
    }

    func makeRefreshControl() -> UIRefreshControl {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
        return control
    }

    @IBAction func refreshAction() {
        guard let stream = stream, let postRepository = postRepository else { return }

        refreshControl?.beginRefreshing()
        postRepository.find(stream: stream, since: stream.posts.first) {
            [weak self] (result: Result<[Post]>) -> Void in
            self?.refreshControl?.endRefreshing()
            self?.didReceivePosts(result: result)
        }
    }

    func didReceivePosts(result: Result<[Post]>) {
        do {
            stream?.posts = try result.unwrap()
            tableView?.reloadData()
        } catch {
            print("\(self): ERROR: \(error)")
        }
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
}
