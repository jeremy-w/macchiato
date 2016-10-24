import UIKit

class ComposePostViewController: UIViewController {
    var postRepository: PostRepository?
    var action: Action = .newThread

    enum Action {
        case newThread
        case newReply(to: Post)

        case editDraft(EditingPost)
        case editDraftReply(EditingPost, to: Post)

        case update(Post)
        case updateReply(Post, to: Post)
    }
    func configure(postRepository: PostRepository, action: Action) {
        self.postRepository = postRepository
        self.action = action
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        registerForKeyboardNotifications()
        insertionPointSwiper = InsertionPointSwiper(editableTextView: textView!)
        loadTextFromAction()
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(notification:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }

    func loadTextFromAction() {
        textView?.text = action.text
    }


    // MARK: - Sends a new post
    private var insertionPointSwiper: InsertionPointSwiper?
    @IBOutlet var textView: UITextView?
    @IBAction func postAction() {
        postRepository?.save(post: post, completion: { result in
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

    var post: EditingPost {
        let updating: String?
        let replyTo: String?
        switch action {
        case .newThread:
            updating = nil
            replyTo = nil

        case let .newReply(to: parent):
            updating = nil
            replyTo = parent.id

        case let .editDraft(original):
            updating = original.updating
            replyTo = original.replyTo

        case let .editDraftReply(original, to: parent):
            assert(original.replyTo == parent.id, "editDraftReply but original.replyTo does not match parent.id: \(original.replyTo) != \(parent.id)")
            updating = original.updating
            replyTo = original.replyTo

        case let .update(current):
            updating = current.id
            replyTo = current.thread?.replyTo

        case let .updateReply(current, to: parent):
            assert(current.thread?.replyTo == parent.id,
                   "updateReply but current.thread.replyTo does not match parent.id: \(current.thread?.replyTo) != \(parent.id)")
            updating = current.id
            replyTo = current.thread?.replyTo
        }
        return EditingPost(content: textView?.text ?? "", updating: updating, replyTo: replyTo)
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


extension ComposePostViewController.Action {
    var text: String {
        switch self {
        case .newThread:
            return ""

        case let .newReply(to: parent):
            return parent.replyTemplate

        case let .editDraft(original):
            return original.content

        case let .editDraftReply(original, to: parent):
            assert(original.replyTo == parent.id, "editDraftReply but original.replyTo does not match parent.id: \(original.replyTo) != \(parent.id)")
            return original.content

        case let .update(current):
            return current.content

        case let .updateReply(current, to: parent):
            assert(current.thread?.replyTo == parent.id,
                   "updateReply but current.thread.replyTo does not match parent.id: \(current.thread?.replyTo) != \(parent.id)")
            return current.content
        }
    }
}
