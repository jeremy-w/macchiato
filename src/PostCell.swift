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

        stackUpAdditionalInfo()
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


    // MARK: - Tacks additional info at the end of the cell
    func stackUpAdditionalInfo() {
        guard let post = self.post, let stack = verticalStack else { return }

        let rows = info(from: post)

        var next = 0
        let count = rows.count
        for view in stack.arrangedSubviews {
            guard let label = view as? UILabel else { continue }
            if next < count {
                label.text = rows[next]
                next += 1
            } else {
                stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }
        for i in next ..< count {
            stack.addArrangedSubview(makeAdditionalInfoLabel(text: rows[i]))
        }
        assert(stack.arrangedSubviews.count == rows.count,
               "stack view should have one view per info row, but \(stack.arrangedSubviews.count) in stack vs \(rows.count) expected")
    }

    func makeAdditionalInfoLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        if #available(iOS 10.0, *) {
            label.adjustsFontForContentSizeCategory = true
        } else {
            // Fallback on earlier versions
        }
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        return label
    }

    func info(from post: Post) -> [String] {
        var info = [String]()
        if post.updated != post.date {
            info.append("updated: \(PostCell.dateFormatter.string(from: post.updated))")
        }
        info.append("client: \(post.client)")
        info.append("id: \(post.id)")
        if post.deleted { info.append("deleted!") }
        if let thread = post.thread {
            info.append("reply to: \(thread.replyTo)")
            info.append("in thread: \(thread.root)")
        }
        if let parentID = post.parentID {
            info.append("parent: \(parentID)")
        }

        let you = post.you
        if you.starred { info.append("🌟") }
        if let pinned = you.pinned { info.append("📌 \(pinned)") }
        if you.reposted { info.append("♻️") }
        if you.muted { info.append("☠️ (you muted this)") }
        if you.cannotSee { info.append("invisible to you! 👻") }
        return info
    }
}
