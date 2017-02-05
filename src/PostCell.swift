import UIKit
import Kingfisher

class PostCell: UITableViewCell {
    @nonobjc static let identifier = "PostCell"
    @IBOutlet var avatar: UIImageView?
    @IBOutlet var author: UILabel?
    @IBOutlet var date: UILabel?
    @IBOutlet var content: UILabel?
    @IBOutlet var infoStack: UIStackView?

    private var post: Post?
    func configure(post: Post) {
        self.post = post

        avatar?.kf.setImage(with: post.account.avatarURL)
        author?.text = post.author
        date?.text = PostCell.dateFormatter.string(from: post.date)
        content?.text = post.content
        content?.attributedText = makeAttributedString(fromHTML: post.html)

        stackUpAdditionalInfo()
    }

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
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.kf.setImage(with: url, placeholder: nil, options: nil, progressBlock: nil, completionHandler: {
                [weak imageView]
                (image, error, cacheType, url) in
                guard let imageView = imageView else { return }
                guard let image = image, image.size.height > 0 else {
                    imageView.removeFromSuperview()
                    return
                }

                let aspectRatio = image.size.width / image.size.height
                NSLayoutConstraint(
                    item: imageView, attribute: .width,
                    relatedBy: .equal,
                    toItem: imageView, attribute: .height,
                    multiplier: aspectRatio, constant: 0)
                    .isActive = true
            })
            stack.addArrangedSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 300.0),
            ])
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
}
