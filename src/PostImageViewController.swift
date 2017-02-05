import UIKit
import Kingfisher

/**
 Used by PostCell to display images in a page view.
 */
class PostImageViewController: UIViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func configure(title: String, imageURL: URL) {
        self.title = title
        self.titleLabel?.text = title
        self.imageURL = imageURL
    }
    private(set) var imageURL: URL?

    @IBOutlet private(set) var titleLabel: UILabel?
    @IBOutlet private(set) var imageView: AnimatedImageView?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel?.text = title
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


    // MARK: - Loads the image or toggles animating on tap
    @IBAction func tapAction() {
        guard isImageLoaded else {
            return beginLoadingImage()
        }

        toggleAnimating()
    }

    var isImageLoaded: Bool {
        guard let imageView = imageView else { return false }

        return imageView.kf.webURL == imageURL
    }

    func beginLoadingImage() {
        guard let imageURL = imageURL else { return }

        imageView?.kf.setImage(with: imageURL)
    }

    func toggleAnimating() {
        guard let imageView = imageView else { return }

        if imageView.isAnimating {
            imageView.stopAnimating()
        } else {
            imageView.startAnimating()
        }
    }
}
