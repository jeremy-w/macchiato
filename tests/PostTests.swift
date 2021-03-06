import XCTest
@testable import Macchiato

class PostTests: XCTestCase {
    func testReplyTemplateOmitsHandlesAsRequested() {
        let authorHandle = "author"
        let other = Post.Mention(name: "other", id: "other", current: "other", isYou: false)
        let author = Post.Mention(name: authorHandle, id: "other", current: authorHandle, isYou: true)
        let post = Post(
            id: "id", account: Account.makeFake(), content: "whatever", html: "<p>whatever</p>", canonicalURL: URL(string: "https://nice.social")!, privacy: "privacy", thread: nil, parentID: nil, client: "client",
            mentions: [other, author],
            created: Date(), updated: Date(), published: Date(), deleted: false, you: Post.You(), stars: [], parent: nil, geo: nil, title: "", source: nil)

        let reply = post.replyTemplate()

        XCTAssertFalse(reply.contains(authorHandle), "should not mention author, but reply text was: \(reply)")
    }
}
