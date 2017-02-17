import Foundation

enum TenCenturiesError: Error {
    case notHTTP(url: URL)
    /**
     Used when we failed to build a URL.
     */
    case badURL(string: String, info: [String: Any])
    case badResponse(url: URL, data: Data?, comment: String)

    case missingField(field: String, object: JSONDictionary)
    case badFieldType(field: String, expected: Any, found: Any, in: JSONDictionary)

    case other(message: String, info: Any)

    /**
     The backend sent us a response like `{ meta: { code: Int, text: String }, data: false }`.

     - `code` is dev info.
     - `text` is user-presentable.
     - `comment` is info added by our infra code providing details on the request and to what URL it went wrong.

     - NOTE: This should always be shown to the user!
     */
    case api(code: Int, text: String, comment: String)

    static func describe(_ error: Error) -> String {
        if case let TenCenturiesError.api(code: _, text: text, comment: _)? = error as? TenCenturiesError {
            return text
        }
        return error.localizedDescription
    }
}
