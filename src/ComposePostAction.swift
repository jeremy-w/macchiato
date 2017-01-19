enum ComposePostAction {
    case newThread
    case newReply(to: Post)

    case editDraft(EditingPost)
    case editDraftReply(EditingPost, to: Post)

    case update(Post)
    case updateReply(Post, to: Post)

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
