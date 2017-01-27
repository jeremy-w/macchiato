import XCTest
@testable import Macchiato

class CurrentUserPropagationTests: XCTestCase {
    let spyingAccountRepository = SpyingAccountRepository()

    // This probably needs rethinking, but the approach we're taking now _should_ work for our limited needs!
    func testWhenUserUpdatesAfterLoadedStreamViewThenStreamViewShowsNewPost() {
        let appDelegate = AppDelegate()

        var fakes = ServicePack.displayingFakeData()
        fakes.sessionManager = FakeSessionManager(loggedInAs: "user@example.com")
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

        print("PERFORM SEGUE")
        masterViewController.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        masterViewController.performSegue(withIdentifier: "showDetail", sender: nil)

        guard let child = appDelegate.streamViewController else {
            return XCTFail("failed to push stream VC")
        }
        child.loadViewIfNeeded()
        XCTAssertNil(child.navigationItem.rightBarButtonItem, "\(child) with stream view \(child.stream?.view) should not be showing new post button before account arrives, but found: \(child.navigationItem.rightBarButtonItem?.title)")
        let _ = expectation(for: NSPredicate(format: "self.navigationItem.rightBarButtonItem != NULL" ), evaluatedWith: child, handler: nil)

        completion(.success(Account.makeFake()))
        waitForExpectations(timeout: 0.5, handler: nil)

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
