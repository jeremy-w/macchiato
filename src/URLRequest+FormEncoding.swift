import Foundation

private typealias FormEncoding = URLRequest
extension FormEncoding {
    mutating func attachURLEncodedFormData(_ queryItems: [URLQueryItem]) {
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard !queryItems.isEmpty else { return }

        // If we have to do this ourselves, or we get into multipart soonish, see:
        // https://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
        var components = URLComponents()
        components.queryItems = queryItems
        guard let urlEncodedQuery = components.percentEncodedQuery else {
            print("ENCODING: WARNING: Empty percent-encoded query created from", queryItems.count, "query items")
            return
        }

        let formURLEncodedQuery = urlEncodedQuery
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "%20", with: "+")
        httpBody = formURLEncodedQuery.data(using: .utf8)
    }
}
