import XCTest
@testable import Macchiato

#if arch(arm) || arch(arm64)
class KeychainIntegration: XCTestCase {
    let user = "Test User"
    let service = "Test Service"

    // Running this repeatedly is implicitly testing that our "update if existing" codepath is working.
    // We'd have to add an (otherwise unused) delete() function to cleanly test adding each time.
    func testRoundtrippingDataThroughKeychain() {
        let password = "test password".data(using: .utf8)!
        guard Keychain.add(account: user, service: service, data: password) else {
            return XCTFail("failed to save to keychain")
        }

        guard let fetched = Keychain.find(account: user, service: service) else {
            return XCTFail("failed to load from keychain")
        }

        XCTAssertEqual(fetched, password, "found password does not match stored")
    }
}
#endif
