import XCTest
@testable import Macchiato

class TenCenturiesPostRepositoryTests: XCTestCase {
    func testBuildsHttpsUrlForEachStreamView() {
        for view: Macchiato.Stream.View in [.global] {
            let url = TenCenturiesPostRepository.url(for: view)
            XCTAssertEqual(url.scheme, "https", "bogus scheme for view=\(view)")
        }
    }

    func testUrlIncludesApiPathComponent() {
        let url = TenCenturiesPostRepository.url(for: .global)
        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("/api/"), "/api/ not found in urlString=\(urlString)")
    }
}
