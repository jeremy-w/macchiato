import UIKit
import Kingfisher

class BylineView: UIView {
    static func makeView() -> BylineView {
        let contents = UINib(nibName: "BylineView", bundle: Bundle(for: self)).instantiate(withOwner: nil, options: nil)
        guard let view = contents.first as? BylineView else {
            preconditionFailure("expected BylineView, found instead: \(contents)")
        }
        return view
    }

    func configure(imageURL: URL, author: String, date: Date) {
        // (jeremy-w/2017-03-13)FIXME: We need to plumb through the full account to do the avatar image view right!
        avatar.kf.setImage(with: imageURL)
        self.author.text = author
        self.date.text = PostCell.dateFormatter.string(from: date)
    }

    @IBOutlet var avatar: AvatarImageView!
    @IBOutlet var author: UILabel!
    @IBOutlet var date: UILabel!
}
