import XCTest
@testable import Macchiato

class FormEncodingTests: XCTestCase {
    func testSetsContentTypeToFormURLEncoded() {
        var request = anyRequest
        request.attachURLEncodedFormData([anyQueryParameter])
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/x-www-form-urlencoded", "Content-Type header value is wrong")
    }

    func testPercentEncodesPlusInQueryParameterValue() {
        let queryItemWithPlusInValue = URLQueryItem(name: "name", value: "a+value")
        var request = anyRequest
        request.attachURLEncodedFormData([queryItemWithPlusInValue])

        guard let body = request.httpBody else {
            return XCTFail("failed to set httpBody")
        }

        guard let string = String(data: body, encoding: .utf8) else {
            return XCTFail("failed to set body to a UTF-8 string, instead: \(body)")
        }

        XCTAssert(string.range(of: "+") == nil, "should not include plus sign after encoding query item \(queryItemWithPlusInValue), but got: \(string)")
        XCTAssertEqual(string.lowercased(), "name=a%2bvalue", "should have encoded + as %2B")
    }

    let anyRequest = URLRequest(url: URL(string: "http://example.com")!)
    let anyQueryParameter = URLQueryItem(name: "name", value: "value")
}
