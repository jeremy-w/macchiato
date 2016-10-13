import Foundation

enum TenCenturiesError: Error {
    case notHTTP(url: URL)
    case badResponse(url: URL, data: Data?, comment: String)
    case parseError(url: URL, object: Any, comment: String)
    case missingField(field: String, object: JSONDictionary)
    case badFieldType(field: String, expected: Any, found: Any, in: JSONDictionary)
    /// The backend sent us a `{ meta: { code: Int, text: String }, data: false }` response.
    case api(code: Int, text: String, comment: String)
}
