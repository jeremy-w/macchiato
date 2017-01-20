import Foundation

protocol RequestAuthenticator {
    /// Stamps a request as originating from a user.
    ///
    /// (If not logged in, it probably won't do anything.)
    func authenticate(request: URLRequest) -> URLRequest
}


struct NopRequestAuthenticator: RequestAuthenticator {
    func authenticate(request: URLRequest) -> URLRequest {
        return request
    }
}
