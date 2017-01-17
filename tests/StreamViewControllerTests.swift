import XCTest
@testable import Macchiato

class StreamViewControllerTests: XCTestCase {
    var subject: StreamViewController?

    override func setUp() {
        subject = StreamViewController(style: .plain)
        XCTAssertNotNil(subject, "should have created StreamViewController")
    }

    func testProvidesPopoverLocationForPostActionSheet() {
        guard let subject = subject else { return }
        let post = Post.makeFake()
        subject.didReceivePosts(result: .success([post]), at: Date())

        let sheet = subject.makePostActionAlert(for: post, at: CGPoint.zero)
        assertAlertIsActionSheetWithValidPopoverLocation(sheet)
    }

    func testProvidesPopoverLocationForPinActionSheet() {
        guard let subject = subject else { return }
        let post = Post.makeFake()
        subject.didReceivePosts(result: .success([post]), at: Date())

        let sheet = subject.makePinAlert(for: post, at: CGPoint.zero)
        assertAlertIsActionSheetWithValidPopoverLocation(sheet)
    }
}


func assertAlertIsActionSheetWithValidPopoverLocation(_ alert: UIAlertController, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(alert.preferredStyle, .actionSheet, "should present alert \(alert.title) as action sheet", file: file, line: line)
    guard UIDevice.current.userInterfaceIdiom == .pad else {
        print(#function, ": Not able to check this on iPhone. Run tests under iPad.")
        return
    }

    guard let presenter = alert.popoverPresentationController else {
        return XCTFail("should have popover presentation controller", file: file, line: line)
    }

    if let delegate = presenter.delegate {
        delegate.prepareForPopoverPresentation?(presenter)
    }

    let item = presenter.barButtonItem
    let sourceView = presenter.sourceView
    XCTAssert(item != nil || sourceView != nil,
              "action sheet \(alert.title) lacks position information of bar-button item or sourceView and sourceRect; this will trigger a crash on iPad", file: file, line: line)
}
