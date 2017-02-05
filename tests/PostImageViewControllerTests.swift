import XCTest
@testable import Macchiato

class PostImageViewControllerTests: XCTestCase {
    let subject = PostImageViewController()

    func testConfigureSetsTitleLabelAndImageURL() {
        let title = "Title"
        let url = URL(string: "example.com/image.jpeg")!

        subject.configure(title: title, imageURL: url)
        subject.loadViewIfNeeded()

        XCTAssertEqual(subject.title, title, "vc title")
        XCTAssertEqual(subject.titleLabel?.text, title, "label title")
        XCTAssertEqual(subject.imageURL, url)
    }

    func testLoadImageActionStartsImageLoading() {
        // Uh, huh. Not so acquainted with Kingfisher as to pull that off. Esp using a fake image.
    }
}
