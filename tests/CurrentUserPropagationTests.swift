import XCTest
@testable import Macchiato

class CurrentUserPropagationTests: XCTestCase {
    let spyingAccountRepository = SpyingAccountRepository()

    // This probably needs rethinking, but the approach we're taking now _should_ work for our limited needs!
    func testWhenUserUpdatesAfterLoadedStreamViewThenStreamViewShowsNewPost() {
        let streamVC = StreamViewController(style: .plain)
        let identity = Identity()
        streamVC.configure(stream: Macchiato.Stream(view: .global), postRepository: FakePostRepository(), identity: identity)

        XCTAssertNil(streamVC.navigationItem.rightBarButtonItem, "no New Post button before identity has account")
        XCTAssertFalse(streamVC.isLoggedIn, "not logged in before identity has account")
        identity.update(using: FakeAccountRepository())
        expectation(forNotification: Notification.Name.identityDidChange.rawValue, object: identity, handler: nil)
        waitForExpectations(timeout: 0.5, handler: nil)

        XCTAssertTrue(streamVC.isLoggedIn, "knows logged in after identity has account")
    }
}


class SpyingAccountRepository: AccountRepository {
    var accountWasCalled: (id: String, completion: (Result<Account>) -> Void)?
    func account(id: String, completion: @escaping (Result<Account>) -> Void) {
        accountWasCalled = (id, completion)
    }

    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }

    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }


    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }

    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }


    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }

    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
    }
}
