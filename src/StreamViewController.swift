import UIKit

class StreamViewController: UITableViewController {
    var stream: Stream?
    var postRepository: PostRepository?
    func configure(stream: Stream, postRepository: PostRepository) {
        self.stream = stream
        self.postRepository = postRepository
        tableView?.reloadData()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
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
