import UIKit
import Kingfisher

protocol PostCellDelegate: class {
    func tapped(link: URL, in cell: PostCell)
    func tapped(image: UIImage?, from url: URL, in cell: PostCell)
    func tapped(actionButton: UIButton, in cell: PostCell)
}

func enableAutoContentSizeUpdates(for view: UIView?) {
    guard let view = view else { return }

    if #available(iOS 10.0, *) {
        if let adjuster = view as? UIContentSizeCategoryAdjusting {
            adjuster.adjustsFontForContentSizeCategory = true
        }
    } else {
        return
    }
}

class PostCell: UITableViewCell {
    @nonobjc static let identifier = "PostCell"
    @IBOutlet var topBin: UIStackView?
    @IBOutlet var avatarToTopBin: NSLayoutConstraint?
    @IBOutlet var avatar: UIImageView?
    @IBOutlet var author: UILabel?
    @IBOutlet var date: UILabel?
    @IBOutlet var content: UILabel?
    @IBOutlet var infoStack: UIStackView?
    @IBOutlet var imageStack: UIStackView?

    private var post: Post?
    func configure(post: Post, headerView: UIView?, delegate: PostCellDelegate? = nil) {
        self.post = post
        self.delegate = delegate

        avatar?.kf.setImage(with: post.account.avatarURL)
        author?.text = post.author
        date?.text = PostCell.dateFormatter.string(from: post.published)

        // Show HTML if parseable, else Markdown.
        if let richText = makeAttributedString(fromHTML: post.html) {
            content?.text = nil
            content?.attributedText = richText
        } else {
            content?.attributedText = nil
            content?.text = post.content
        }

        highlightIfMention()

        if let topBin = topBin {
            emptyOut(topBin)
            headerView.map { topBin.addArrangedSubview($0) }
            avatarToTopBin?.constant = (headerView != nil) ? 8 : 0
        }

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
        enableAutoContentSizeUpdates(for: author)
        enableAutoContentSizeUpdates(for: date)
        enableAutoContentSizeUpdates(for: content)
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


    // MARK: - Alters background color to reflect mention status
    func highlightIfMention() {
        let isMention = (post?.you.wereMentioned ?? false)
        backgroundColor = isMention ? #colorLiteral(red: 0.95, green: 0.9866666667, blue: 1, alpha: 1) : UIColor.white
    }


    // MARK: - Forwards action button tap
    @objc(actionButtonAction:)
    @IBAction func actionButtonAction(sender: UIButton) {
        delegate?.tapped(actionButton: sender, in: self)
    }


    // MARK: - Tacks additional info at the end of the cell
    func stackUpAdditionalInfo() {
        guard let stack = infoStack else { return }

        emptyOut(stack)
        addInfoLabels()
        addLinkButtons()

        guard let imageStack = imageStack else { return }
        emptyOut(imageStack)
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
        enableAutoContentSizeUpdates(for: label)
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        return label
    }

    func info(from post: Post) -> [String] {
        var info = [String]()
        if post.created != post.published {
            info.append("created: \(PostCell.dateFormatter.string(from: post.created))")
        }
        if post.updated != post.created {
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
            button.titleLabel?.textAlignment = .natural

            button.addTarget(self, action: #selector(linkButtonAction), for: .touchUpInside)
            objc_setAssociatedObject(button, &PostCell.associatedURL, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            button.accessibilityTraits &= ~UIAccessibilityTraitButton
            button.accessibilityTraits |= UIAccessibilityTraitLink

            enableAutoContentSizeUpdates(for: button)

            stack.addArrangedSubview(button)
        }
    }

    @IBAction func linkButtonAction(sender: UIButton) {
        guard let url = objc_getAssociatedObject(sender, &PostCell.associatedURL) as? URL else {
            print("POSTCELL: WARNING: Failed to retrieve URL for button:", sender, "- in post with ID", post?.id as Any)
            return
        }

        print("POSTCELL: INFO: Link button tapped for URL:", url)
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
        guard let text = content?.attributedText, let stack = imageStack else { return }

        let imageURLs = imageLinks(in: text)
        for url in imageURLs {
            let imageView = makeImageView(loading: url)
            stack.addArrangedSubview(imageView)
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

    static var associatedURL = "com.jeremywsherman.Macchiato.PostCell.associatedURL"
    @IBAction func imageTapAction(sender: UITapGestureRecognizer) {
        guard let imageView = sender.view as? UIImageView else {
            print("POSTCELL: ERROR: Image tapped, but gesture recognizer is not tied to an image view:", sender)
            return
        }

        guard let url = objc_getAssociatedObject(imageView, &PostCell.associatedURL) as? URL else {
            print("POSTCELL: ERROR: Image tapped, but no URL associated with the image view:", imageView)
            return
        }

        print("POSTCELL: INFO: Image tapped for URL:", url)
        delegate?.tapped(image: imageView.image, from: url, in: self)
    }

    func makeImageView(loading url: URL) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 300.0),
        ])

        imageView.kf.indicatorType = .activity
        imageView.kf.setImage(with: url)
        objc_setAssociatedObject(imageView, &PostCell.associatedURL, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        assert(objc_getAssociatedObject(imageView, &PostCell.associatedURL) as? URL == url, "set and get failed")

        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapAction)))
        imageView.isUserInteractionEnabled = true

        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = NSLocalizedString("Image", comment: "accessibility label")
        imageView.accessibilityHint = NSLocalizedString("Tap to view full image", comment: "accessibility hint")
        imageView.accessibilityTraits |= UIAccessibilityTraitLink
        return imageView
    }
}
