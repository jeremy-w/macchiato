import XCTest
@testable import Macchiato

class TenCenturiesServiceTests {
    func testBaseUrlIsAUrl() {
        XCTAssertNotNil(TenCenturies.baseURL)
    }
}
