import XCTest
@testable import Macchiato

class KeychainIntegration: XCTestCase {
    let user = "Test User"
    let service = "Test Service"

    func testRoundtrippingDataThroughKeychain() {
        let password = "test password".data(using: .utf8)!
        var generic = Data()
        generic.append(contentsOf: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        guard Keychain.add(account: user, service: service, data: password, generic: generic) else {
            return XCTFail("failed to save to keychain")
        }

        guard let fetched = Keychain.find(account: user, service: service, generic: generic) else {
            return XCTFail("failed to load from keychain")
        }

        XCTAssertEqual(fetched, password, "found password does not match stored")
    }
}
