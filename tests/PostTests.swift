import XCTest
@testable import Macchiato

class PostTests: XCTestCase {
    func testReplyTemplateOmitsHandlesAsRequested() {
        let authorHandle = "author"
        let other = Post.Mention(name: "other", id: "other", current: "other")
        let author = Post.Mention(name: authorHandle, id: "other", current: authorHandle)
        let post = Post(
            id: "id", account: Account.makeFake(), date: Date(), content: "whatever", privacy: "privacy", thread: nil, parentID: nil, client: "client",
            mentions: [other, author],
            updated: Date(), deleted: false, you: Post.You())

        let reply = post.replyTemplate(notMentioning: [authorHandle])

        XCTAssertFalse(reply.contains(authorHandle), "should not mention author, but reply text was: \(reply)")
    }
}
