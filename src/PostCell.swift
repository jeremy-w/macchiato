import UIKit

class PostCell: UITableViewCell {
    @nonobjc static let identifier = "PostCell"
    @IBOutlet var author: UILabel?
    @IBOutlet var date: UILabel?
    @IBOutlet var content: UILabel?
    @IBOutlet var verticalStack: UIStackView?

    private var post: Post?
    func configure(post: Post) {
        self.post = post

        author?.text = post.author
        date?.text = PostCell.dateFormatter.string(from: post.date)
        content?.text = post.content
    }

    init() {
        super.init(style: .default, reuseIdentifier: PostCell.identifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @nonobjc static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short  // long adds timezone
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}
