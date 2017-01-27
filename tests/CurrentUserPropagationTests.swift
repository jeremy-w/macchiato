import XCTest
@testable import Macchiato

class CurrentUserPropagationTests: XCTestCase {
    // This probably needs rethinking, but the approach we're taking now _should_ work for our limited needs!
    func testWhenUserUpdatesAfterLoadedStreamViewThenStreamViewShowsNewPost() {
        let appDelegate = AppDelegate()

        var fakes = ServicePack.displayingFakeData()

        let stubSessionManager = FakeSessionManager()
        stubSessionManager.loggedInAccountName = "user@example.com"
        fakes.sessionManager = stubSessionManager

        let spyingAccountRepository = SpyingAccountRepository()
        fakes.accountRepository = spyingAccountRepository

        appDelegate.services = fakes

        let window = UIWindow()
        window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        appDelegate.window = window

        let _ = appDelegate.didFinishLaunching(ignoreTestMode: true)

        guard let (accountName, completion) = spyingAccountRepository.accountWasCalled else {
            return XCTFail("failed to request account even though logged in")
        }
        XCTAssertEqual(accountName, "me", "should have fetched current user")

        guard let masterViewController = appDelegate.masterViewController else {
            return XCTFail("failed to load master VC")
        }

        masterViewController.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        masterViewController.performSegue(withIdentifier: "showDetail", sender: nil)

        guard let child = appDelegate.streamViewController else {
            return XCTFail("failed to push stream VC")
        }
        XCTAssertNil(child.navigationItem.rightBarButtonItem, "should not be showing new post button before account arrives, but found: \(child.navigationItem.rightBarButtonItem?.title)")

        completion(.success(Account.makeFake()))

        XCTAssertTrue(child.isLoggedIn, "child should be logged in after account fetched")
        XCTAssertNotNil(child.navigationItem.rightBarButtonItem, "child should have right bar button item after account fetched")
    }
}


class SpyingAccountRepository: AccountRepository {
    var accountWasCalled: (id: String, completion: (Result<Account>) -> Void)?
    func account(id: String, completion: @escaping (Result<Account>) -> Void) {
        accountWasCalled = (id, completion)
    }
}
