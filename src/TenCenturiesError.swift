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
        guard let ten = error as? TenCenturiesError else {
            return error.localizedDescription
        }

        switch ten {
        case let .notHTTP(url: url):
            return String.localizedStringWithFormat(
                NSLocalizedString("Received non-HTTP response from URL: %@", comment: "error text"),
                url.absoluteString)

        case let .badURL(string: string, info: _):
            return String.localizedStringWithFormat(
                NSLocalizedString("Failed to create valid URL with: %@", comment: "error text"),
                string)

        case let .badResponse(url: url, data: _, comment: comment):
            return String.localizedStringWithFormat(
                NSLocalizedString("Incomprehensible 10C API response from URL: %@ - %@", comment: "error text"),
                url.absoluteString, comment)

        case let .missingField(field: field, object: object):
            return String.localizedStringWithFormat(
                NSLocalizedString("Missing field “%@” in: %@", comment: "error text"),
                field, object)

        case let .badFieldType(field: field, expected: expected, found: found, in: object):
            return String.localizedStringWithFormat(
                NSLocalizedString("Expected field “%@” to be a “%@”, but found a “%@” in: %@", comment: "error text"),
                field, String(describing: expected), String(reflecting: found), object)

        case let .other(message: message, info: info):
            return String(format: "%@: %@", message, String(reflecting: info))

        case let .api(code: _, text: text, comment: _):
            return text
        }
    }
}
