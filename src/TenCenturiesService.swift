import Foundation

enum TenCenturies {
    static let baseURL = URL(string: "https://api.10centuries.org")!
}

/**
 The basic protocol used to communicate with any 10Centuries service.

 Generic HTTP request issuing and response parsing functionality is provided
 through protocol extension methods.
 */
protocol TenCenturiesService {
    var session: URLSession { get }
    var authenticator: RequestAuthenticator { get }
    func send(request: URLRequest, completion: @escaping (Result<JSONDictionary>) -> Void) -> URLSessionTask
}

extension TenCenturiesService {
    /**
     Sends a request. The request will automatically be authenticated using `authenticator` prior to transmission.

     - parameter completion: Called with the response's JSON dictionary, or an error, whether HTTP or 10C.
     */
    func send(request unauthenticated: URLRequest, completion: @escaping (Result<JSONDictionary>) -> Void) -> URLSessionTask {
        precondition(unauthenticated.url != nil, "request without URL: \(String(reflecting: unauthenticated))")
        let request = authenticator.authenticate(request: unauthenticated)
        let url = request.url!  // swiftlint:disable:this
        print("API: INFO: BEGIN \(request.url)")
        let task = session.dataTask(with: request) { (data, response, error) in
            let result = Result.of { () throws -> JSONDictionary in
                do {
                    guard let response = response as? HTTPURLResponse else {
                        throw TenCenturiesError.notHTTP(url: url)
                    }
                    /*
                     Rate limit headers look like:

                     X-RateLimit-Limit: 500
                     X-RateLimit-Remaining: 490
                     X-RateLimit-Reset: 2866
                     */
                    let limits = RateLimit(headers: response.allHeaderFields)
                    print("API: INFO: END \(url): \(response.statusCode): \(data) \(error) "
                        + "- RATELIMIT: \(limits.map { String(reflecting: $0) } ?? "(headers not found)")")

                    guard let data = data else {
                        throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                    }

                    guard error == nil else {
                        throw error!
                    }

                    let object = try JSONSerialization.jsonObject(with: data, options: [])
                    //                print("API: VDEBUG: \(url): \(String(reflecting: object))")

                    guard let dict = object as? JSONDictionary
                        , let meta = dict["meta"] as? JSONDictionary
                        else {
                            throw TenCenturiesError.badResponse(url: url, data: data, comment: "bogus object in body")
                    }

                    if let errorMessage = meta["text"] as? String {
                        let code = meta["code"] as? Int ?? -1
                        throw TenCenturiesError.api(code: code, text: errorMessage, comment: "failed with: \(String(reflecting: request)) to \(url)")
                    }
                    return dict
                }
            }
            print("API: DEBUG: \(request.url): Extracted response body: \(result)")
            completion(result)
        }
        task.resume()
        return task
    }
}
