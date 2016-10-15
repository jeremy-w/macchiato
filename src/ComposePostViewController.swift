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
}
