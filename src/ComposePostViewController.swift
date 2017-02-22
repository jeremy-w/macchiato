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
    var photoUploader: PhotoUploader = TenCenturiesCDNPhotoUploader()
    @objc(uploadImageAction:)
    @IBAction func uploadImageAction(sender: UIButton) {
        print("COMPOSER/IMAGE: INFO: Upload image action invoked")
        let provider: PhotoProvider = ImagePickerPhotoProvider(controller: self, sender: sender)
        provider.requestOne { [weak self] photo in
            self?.didReceivePhoto(photo, from: provider)
        }
    }

    func didReceivePhoto(_ photo: Photo?, from provider: PhotoProvider) {
        print("COMPOSER/IMAGE: INFO: Image provider", provider, "gave photo:", photo as Any)
        guard let photo = photo else { return }

        photoUploader.upload(photo) { [weak self] result in
            self?.didUpload(photo: photo, result: result)
        }
    }

    func didUpload(photo: Photo, result: Result<URL>) {
        print("COMPOSER/IMAGE: INFO: Uploading photo", photo, "had result:", result)
        do {
            let location = try result.unwrap()
            self.insertImageMarkdown(title: photo.title, href: location)
        } catch {
            toast(error: error, prefix: NSLocalizedString("Photo Upload Failed", comment: "toast error prefix"))
        }
    }

    func insertImageMarkdown(title: String, href: URL) {
        guard let textView = textView else {
            print("COMPOSER/IMAGE: WARNING: No text view, nowhere to stick URL \(href) for image titled \(title)!")
            return
        }

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
    let data: Data
}


protocol PhotoProvider {
    func requestOne(completion: @escaping (Photo?) -> Void)
}


class ImagePickerPhotoProvider: NSObject, PhotoProvider, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let controller: UIViewController
    let sender: UIButton
    init(controller: UIViewController, sender: UIButton) {
        self.controller = controller
        self.sender = sender
    }

    var requestCompletion: (Photo?) -> Void = { _ in }
    func requestOne(completion: @escaping (Photo?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) else {
            print("IMAGE PICKER: ERROR: Photos Album unavailable")
            completion(nil)
            return
        }

        requestCompletion = completion
        let picker = UIImagePickerController()
        picker.allowsEditing = false  // true shows funky crop-box without any way to change rect!
        picker.delegate = self
        if let presenter = picker.popoverPresentationController {
            let view = sender.titleLabel ?? sender
            presenter.sourceView = view
            presenter.sourceRect = view.bounds
        }

        print("IMAGE PICKER: INFO: Showing picker")
        controller.present(picker, animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("IMAGE PICKER: INFO: User canceled")
        defer { controller.dismiss(animated: true, completion: nil) }
        finish(with: nil)
    }

    func finish(with photo: Photo?) {
        requestCompletion(photo)
        requestCompletion = { _ in }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        defer { controller.dismiss(animated: true, completion: nil) }

        print("IMAGE PICKER: DEBUG: User picked a photo: info", info)
        let edited = info[UIImagePickerControllerEditedImage] as? UIImage
        let raw = info[UIImagePickerControllerOriginalImage] as? UIImage
        guard let image = edited ?? raw else {
            print("IMAGE PICKER: ERROR: Claimed finished picking, but neither edited nor raw image present! info", info)
            finish(with: nil)
            return
        }

        // (jeremy-w/2017-02-22)FIXME: Fish out original data from Photo Library
        guard let data = UIImageJPEGRepresentation(image, 0.9) ?? UIImagePNGRepresentation(image) else {
            print("IMAGE PICKER: ERROR: Failed to get data for image", image, "- info", info)
            finish(with: nil)
            return
        }

        let title = NSLocalizedString("Image", comment: "photo title placeholder")
        let photo = Photo(title: title, data: data)
        finish(with: photo)
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
