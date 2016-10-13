import Foundation

private typealias FormEncoding = URLRequest
extension FormEncoding {
    mutating func attachURLEncodedFormData(_ queryItems: [URLQueryItem]) {
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // If we have to do this ourselves, or we get into multipart soonish, see:
        // https://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
        var components = URLComponents()
        components.queryItems = queryItems
        let query = components.percentEncodedQuery
        httpBody = query?.data(using: .utf8)
    }
}
