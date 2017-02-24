import UIKit

protocol ComposePostViewControllerDelegate {
    func uploadImage(for controller: ComposePostViewController, sender: UIButton, then continuation: @escaping ((title: String, href: URL)?) -> Void)
}

class ComposePostViewController: UIViewController {
    var postRepository: PostRepository?
    var action: ComposePostAction = .newThread
    var author: Account?
    var delegate: ComposePostViewControllerDelegate?

    func configure(delegate: ComposePostViewControllerDelegate, postRepository: PostRepository, action: ComposePostAction, author: Account) {
        self.delegate = delegate
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
    @objc(uploadImageAction:)
    @IBAction func uploadImageAction(sender: UIButton) {
        print("COMPOSER/IMAGE: INFO: Upload image action invoked")
        delegate?.uploadImage(for: self, sender: sender, then: { [weak self] (result) in
            guard let me = self else { return }

            guard let (title: title, href: href) = result else {
                print("COMPOSER/IMAGE: INFO: Upload image failed; assuming user already informed")
                return
            }

            DispatchQueue.main.async {
                me.insertImageMarkdown(title: title, href: href)
            }
        })
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
    let mime: String
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
        let jpeg = UIImageJPEGRepresentation(image, 0.9)
        guard let data = jpeg ?? UIImagePNGRepresentation(image) else {
            print("IMAGE PICKER: ERROR: Failed to get data for image", image, "- info", info)
            finish(with: nil)
            return
        }

        let title = NSLocalizedString("Image", comment: "photo title placeholder")
        let mime = (jpeg != nil) ? "image/jpeg" : "image/png"
        let photo = Photo(title: title, mime: mime, data: data)
        finish(with: photo)
    }
}


protocol PhotoUploader {
    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void)
}


class TenCenturiesCDNPhotoUploader: PhotoUploader, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }

    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void) {
        let url = URL(string: "https://chat.10centuries.org/uploads.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let boundary = multipartBoundary(for: Date())
        request.setValue("multipart/form-data; boundary=\"\(boundary)\"", forHTTPHeaderField: "Content-Type")
        request.httpBody = asMultipartEnclosure(photo, boundary: boundary)

        _ = send(request: request) { (result: Result<JSONDictionary>) in
            do {
                let dict = try result.unwrap()
                let isGood = try unpack(dict, "isGood") as String
                guard isGood == "Y" else {
                    let result = try? unpack(dict, "result") as String
                    let text = result ?? NSLocalizedString("Uploaded photo deemed no good by 10C CDN", comment: "error message")
                    completion(.failure(TenCenturiesError.api(code: -1, text: text, comment: "photo upload deemed NOT GOOD")))
                    return
                }

                guard let url = URL(string: try unpack(dict, "cdnurl")) else {
                    let urlParsingFailed = NSLocalizedString("Failed to parse uploaded photo's CDN URL", comment: "error message")
                    let error = TenCenturiesError.other(message: urlParsingFailed, info: dict["cdnurl"] as Any)
                    completion(.failure(error))
                    return
                }
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func send(request unauthenticated: URLRequest, completion: @escaping (Result<JSONDictionary>) -> Void) -> URLSessionTask {
        let request = authenticator.authenticate(request: unauthenticated)
        let url = request.url!  // swiftlint:disable:this
        print("API: INFO: BEGIN \(request.url) \(request)")
        print("API: DEBUG: BEGIN:\n\(debugInfo(for: request))")
        let task = session.dataTask(with: request) { (data, response, error) in
            let result = Result.of { () throws -> JSONDictionary in
                do {
                    guard let response = response as? HTTPURLResponse else {
                        throw TenCenturiesError.notHTTP(url: url)
                    }
                    /*
                     Rate limit headers look like:

                     X-RateLimit-Limit: 500
                     X-RateLimit-Remaining: 490
                     X-RateLimit-Reset: 2866
                     */
                    let limits = RateLimit(headers: response.allHeaderFields)
                    print("API: INFO: END \(url): \(response.statusCode): \(data) \(error) "
                        + "- RATELIMIT: \(limits.map { String(reflecting: $0) } ?? "(headers not found)")")
                    print("API: DEBUG: END: \(response)\n\(debugInfo(for: response))")

                    guard let data = data else {
                        throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                    }

                    guard error == nil else {
                        throw error!
                    }

                    let object = try JSONSerialization.jsonObject(with: data, options: [])
                    guard let dict = object as? JSONDictionary else {
                            throw TenCenturiesError.badResponse(url: url, data: data, comment: "body is not a dict")
                    }
                    return dict
                }
            }
            print("API: DEBUG: \(request.url): Extracted response body: \(result)")
            completion(result)
        }
        task.resume()
        return task
    }

    func asMultipartEnclosure(_ photo: Photo, boundary: String) -> Data {
        let crlf = "\r\n"
        let chunkHeader = crlf + "--\(boundary)" + crlf
            + "Content-Disposition: form-data; name=\"file\"; filename=\"\(photo.title)\"" + crlf
            + "Content-Transfer-Encoding: binary" + crlf
            + "Content-Type: \(photo.mime)" + crlf
            + crlf
        let chunkFooter = crlf + "--\(boundary)--" + crlf
        let enclosure = chunkHeader.data(using: .utf8)! + photo.data + chunkFooter.data(using: .utf8)!
        return enclosure
    }

    func multipartBoundary(for date: Date) -> String {
        let maybeTooLong = "com.jeremywsherman.Macchiato-" + String(describing: date.timeIntervalSince1970)
        let limit = maybeTooLong.index(maybeTooLong.startIndex, offsetBy: 70, limitedBy: maybeTooLong.endIndex)
        let boundary = limit.map({ maybeTooLong[maybeTooLong.startIndex ..< $0] }) ?? maybeTooLong
        return boundary
    }
}
