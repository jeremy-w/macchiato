import Foundation

enum TenCenturiesError: Error {
    case notHTTP(url: URL)
    /**
     Used when we failed to build a URL.
     */
    case badURL(string: String, info: [String: Any])
    case badResponse(url: URL, data: Data?, comment: String)

    case parseError(url: URL, object: Any, comment: String)
    case missingField(field: String, object: JSONDictionary)
    case badFieldType(field: String, expected: Any, found: Any, in: JSONDictionary)

    /**
     The backend sent us a response like `{ meta: { code: Int, text: String }, data: false }`.

     - `code` is dev info.
     - `text` is user-presentable.
     - `comment` is info added by our infra code providing details on the request and to what URL it went wrong.

     - NOTE: This should always be shown to the user!
     */
    case api(code: Int, text: String, comment: String)
}
