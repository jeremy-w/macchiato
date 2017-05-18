typealias PostID = String

struct EditingPost {
    var content: String

    let channel = 1
    let updating: PostID?
    let replyTo: PostID?
}


extension EditingPost {
    init(content: String, for action: ComposePostAction) {
        let updating: PostID?
        let replyTo: PostID?
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
            assert(original.replyTo == parent.id,
                   "editDraftReply but original.replyTo does not match parent.id: \(String(describing: original.replyTo)) != \(parent.id)")
            updating = original.updating
            replyTo = original.replyTo

        case let .update(current):
            updating = current.id
            replyTo = current.thread?.replyTo

        case let .updateReply(current, to: parent):
            assert(current.thread?.replyTo == parent.id,
                   "updateReply but current.thread.replyTo does not match parent.id: \(String(describing: current.thread?.replyTo)) != \(parent.id)")
            updating = current.id
            replyTo = current.thread?.replyTo
        }
        self.init(content: content, updating: updating, replyTo: replyTo)
    }
}
