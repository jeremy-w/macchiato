import UIKit
import Kingfisher

protocol PostCellDelegate: class {
    func tapped(link: URL, in cell: PostCell)
    func tapped(image: UIImage?, from url: URL, in cell: PostCell)

    func willChangeHeight(of cell: PostCell)
    func didChangeHeight(of cell: PostCell)
}

class PostCell: UITableViewCell {
    @nonobjc static let identifier = "PostCell"
    @IBOutlet var avatar: UIImageView?
    @IBOutlet var author: UILabel?
    @IBOutlet var date: UILabel?
    @IBOutlet var content: UILabel?
    @IBOutlet var infoStack: UIStackView?

    private var post: Post?
    func configure(post: Post, delegate: PostCellDelegate? = nil) {
        self.post = post
        self.delegate = delegate

        avatar?.kf.indicatorType = .activity
        avatar?.kf.setImage(with: post.account.avatarURL)
        author?.text = post.author
        date?.text = PostCell.dateFormatter.string(from: post.date)
        content?.text = post.content
        content?.attributedText = makeAttributedString(fromHTML: post.html)

        stackUpAdditionalInfo()
    }
    weak var delegate: PostCellDelegate?

    init() {
        super.init(style: .default, reuseIdentifier: PostCell.identifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        roundCorners(of: avatar)
    }

    func roundCorners(of view: UIView?) {
        guard let view = view else { return }

        view.layer.masksToBounds = true
        view.layer.cornerRadius = 8
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
        guard let stack = infoStack else { return }

        emptyOut(stack)
        addInfoLabels()
        addLinkButtons()
        addImageViews()
    }

    func emptyOut(_ view: UIView) {
        for view in view.subviews {
            view.removeFromSuperview()
        }
    }


    // MARK: - Info labels
    func addInfoLabels() {
        guard let post = post, let stack = infoStack else { return }

        for text in info(from: post) {
            stack.addArrangedSubview(makeAdditionalInfoLabel(text: text))
        }
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


    // MARK: - Link buttons
    func addLinkButtons() {
        guard let text = content?.attributedText, let stack = infoStack else { return }

        let urls = links(in: text)
        for url in urls {
            let button = UIButton(type: .system)
            button.setTitle(url.absoluteString, for: .normal)
            button.addTarget(self, action: #selector(linkButtonAction), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    @IBAction func linkButtonAction(sender: UIButton) {
        guard let absoluteString = sender.title(for: .normal)
        , let url = URL(string: absoluteString) else {
            print("POSTCELL: WARNING: Failed to recreate URL for button:", sender, "- in post with ID", post?.id as Any)
            return
        }

        // (jeremy-w/2017-02-04)TODO: Shoot the URL over to a delegate.
        print("POSTCELL: DEBUG: You tapped on URL:", url)
        delegate?.tapped(link: url, in: self)
    }

    func links(in text: NSAttributedString) -> [URL] {
        var urls = [URL]()
        text.enumerateAttribute(NSLinkAttributeName, in: NSRange(location: 0, length: text.length), options: []) { (value, range, shouldStop) in
            // Gets called also for ranges where the attribute is nil.
            guard let value = value else { return }

            if let url = value as? URL {
                urls.append(url)
                return
            } else if let string = value as? String, let url = URL(string: string) {
                urls.append(url)
                return
            } else {
                print("POSTCELL: WARNING: Failed to create URL from HREF:", value as Any, "- in post with ID", post?.id as Any)
                return
            }
        }
        return urls
    }


    // MARK: - Image displays
    func addImageViews() {
        guard let text = content?.attributedText, let stack = infoStack else { return }

        let imageURLs = imageLinks(in: text)
        for url in imageURLs {
            let imageView = makeImageView(loading: url)
            stack.addArrangedSubview(imageView)

            imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapAction)))
        }
    }

    func imageLinks(in text: NSAttributedString) -> [URL] {
        var urls = [URL]()
        text.enumerateAttribute(
            TenCenturiesHTMLParser.imageSourceURLAttributeName,
            in: NSRange(location: 0, length: text.length),
            options: []) {
                (value, range, shouldStop) in
                guard let url = value as? URL else { return }

                urls.append(url)
        }
        return urls
    }

    @IBAction func imageTapAction(sender: UIImageView) {
        guard let url = sender.kf.webURL else { return }

        delegate?.tapped(image: sender.image, from: url, in: self)
    }

    func makeImageView(loading url: URL) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.kf.indicatorType = .activity
        imageView.kf.setImage(with: url)
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 300.0),
        ])
        return imageView
    }
}
