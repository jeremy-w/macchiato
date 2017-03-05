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
        avatar.kf.setImage(with: imageURL)
        self.author.text = author
        self.date.text = PostCell.dateFormatter.string(from: date)
    }

    @IBOutlet var avatar: UIImageView!
    @IBOutlet var author: UILabel!
    @IBOutlet var date: UILabel!
}
