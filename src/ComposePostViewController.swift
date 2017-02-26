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
        positionInsertionPointInText()
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

    func positionInsertionPointInText() {
        guard let textView = textView else { return }
        defer { textView.becomeFirstResponder() }

        guard let text = textView.text else {
            textView.selectedRange = NSRange(location: 0, length: 0)
            return
        }

        let nstext = text as NSString
        var mentionsRange = NSRange(location: 0, length: 0)
        nstext.enumerateSubstrings(
            in: NSRange(location: 0, length: nstext.length),
            options: [.byWords, .substringNotRequired]
        ) { (_, wordRange, enclosingRange, done) in
            // When I let it give me the substring, I got gibberish. Weird!
            // Word range omits at-signs. DERP!
            let word = nstext.substring(with: wordRange)
            guard word.hasPrefix("@") else {
                done.pointee = true
                return
            }

            mentionsRange.length = NSMaxRange(wordRange)
        }

        let select = NSRange(location: NSMaxRange(mentionsRange), length: 0)
        textView.selectedRange = select
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

        let previousTitle = sender.currentTitle
        sender.setTitle(NSLocalizedString("Uploading…", comment: "button title"), for: .normal)
        sender.isEnabled = false
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, sender)

        delegate?.uploadImage(for: self, sender: sender, then: { [weak self] (result) in
            DispatchQueue.main.async {
                sender.setTitle(previousTitle, for: .normal)
                sender.isEnabled = true
            }

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

        let markdown = "![\(title)](\(href.absoluteString))"
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
