import UIKit

class ComposePostViewController: UIViewController {
    var postRepository: PostRepository?
    var action: ComposePostAction = .newThread
    var author: Account?

    func configure(postRepository: PostRepository, action: ComposePostAction, author: Account) {
        self.postRepository = postRepository
        self.action = action
        self.author = author
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        registerForKeyboardNotifications()
        insertionPointSwiper = InsertionPointSwiper(editableTextView: textView!)
        loadTextFromAction()
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(notification:)),
            name: .UIKeyboardWillChangeFrame, object: nil)
    }

    func loadTextFromAction() {
        let authorsUsername = [author?.username].flatMap({ $0 })
        textView?.text = action.template(notMentioning: authorsUsername)
    }


    // MARK: - Sends a new post
    private var insertionPointSwiper: InsertionPointSwiper?
    @IBOutlet var textView: UITextView?
    @IBAction func postAction() {
        postRepository?.save(post: EditingPost(content: textView?.text ?? "", for: action), completion: { result in
            switch result {
            case .success:
                // (jws/2016-10-15)TODO: Should refresh any streams containing this
                toast(title: NSLocalizedString("Posted!", comment: "title"))

            case let .failure(error):
                // (jws/2016-10-15)FIXME: Save as draft and allow to retry!
                let details: String
                if case let TenCenturiesError.api(code: _, text: text, comment: _) = error {
                    details = text
                } else {
                    details = "😔"
                }
                toast(title: NSLocalizedString("Posting Failed: ", comment: "title") + details)
            }
        })
    }


    // MARK: - Attaches an image
    var photos: PhotoProvider = ImagePickerPhotoProvider()
    var photoUploader: PhotoUploader = TenCenturiesCDNPhotoUploader()
    @IBAction func attachImageAction() {
        photos.requestOne { [weak self] photo in
            self?.didReceivePhoto(photo)
        }
    }

    func didReceivePhoto(_ photo: Photo?) {
            guard let photo = photo else { return }

            photoUploader.upload(photo) { [weak self] result in
                self?.didUpload(photo: photo, result: result)
        }
    }

    func didUpload(photo: Photo, result: Result<URL>) {
        do {
            let location = try result.unwrap()
            self.insertImageMarkdown(title: photo.title, href: location)
        } catch {
            toast(error: error, prefix: NSLocalizedString("Photo Upload Failed", comment: "toast error prefix"))
        }
    }

    func insertImageMarkdown(title: String, href: URL) {
        guard let textView = textView else { return }

        let markdown = "![\(title)](\(href.absoluteString)"
        textView.insertText(markdown)
    }


    // MARK: - Moves out of the way of the keyboard
    @IBOutlet var bottomConstraint: NSLayoutConstraint?
    @objc func keyboardWillChangeFrame(notification note: NSNotification) {
        guard let window = view.window, let constraint = bottomConstraint else { return }
        guard let value = note.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
        let topEdgeOfKeyboard = window.convert(value.cgRectValue, from: nil).minY
        constraint.constant = window.bounds.height - topEdgeOfKeyboard
    }
}


struct Photo {
    let title: String
}


protocol PhotoProvider {
    func requestOne(completion: @escaping (Photo?) -> Void)
}


class ImagePickerPhotoProvider: PhotoProvider {
    func requestOne(completion: @escaping (Photo?) -> Void) {
        completion(nil)
    }
}


protocol PhotoUploader {
    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void)
}


class TenCenturiesCDNPhotoUploader: PhotoUploader {
    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void) {
        completion(.failure(notYetImplemented))
    }
}
