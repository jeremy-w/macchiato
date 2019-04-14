import Foundation

protocol RequestAuthenticator {
    var canAuthenticate: Bool { get }

    /// Stamps a request as originating from a user.
    ///
    /// (If not logged in, it probably won't do anything.)
    func authenticate(request: URLRequest) -> URLRequest
}


struct NopRequestAuthenticator: RequestAuthenticator {
    let canAuthenticate = false

    func authenticate(request: URLRequest) -> URLRequest {
        return request
    }
}
