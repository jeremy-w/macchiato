import UIKit

class PostCell: UITableViewCell {
    @nonobjc static let identifier = "PostCell"
    @IBOutlet var author: UILabel?
    @IBOutlet var date: UILabel?
    @IBOutlet var content: UILabel?

    private var post: Post?
    func configure(post: Post) {
        self.post = post

        author?.text = post.author
        date?.text = String(describing: post.date)
        content?.text = post.content
    }

    init() {
        super.init(style: .default, reuseIdentifier: PostCell.identifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
