import Foundation

enum TenCenturies {
    static let baseURL = URL(string: "https://nice.social")!
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
        print("API: INFO: BEGIN \(String(describing: request.url)) \(request)")
        print("API: DEBUG: BEGIN:\n\(debugInfo(for: request))")
        let task = session.dataTask(with: request) { (data, response, error) in
            let result = Result.of { () throws -> JSONDictionary in
                do {
                    guard error == nil else {
                        throw error!
                    }

                    guard let response = response as? HTTPURLResponse else {
                        throw TenCenturiesError.notHTTP(url: url)
                    }

                    print("API: INFO: END \(url): \(response.statusCode): \(String(describing: data)) \(String(describing: error)) ")
                    print("API: DEBUG: END: \(response)\n\(debugInfo(for: response))")

                    guard let data = data else {
                        throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                    }

                    let object: Any
                    do {
                        object = try JSONSerialization.jsonObject(with: data, options: [])
                    } catch {
                        print("API: ERROR: Data was not JSON. Let's hope it's plaintext. error=\(error)")
                        object = ["meta": ["text": String(bytes: data, encoding: .utf8)]]
                    }

                    guard let dict = object as? JSONDictionary
                        , let meta = dict["meta"] as? JSONDictionary
                        else {
                            throw TenCenturiesError.badResponse(url: url, data: data, comment: "body is not a dict or meta is missing")
                    }

                    if let errorMessage = meta["text"] as? String {
                        let code = meta["code"] as? Int ?? -1
                        throw TenCenturiesError.api(code: code, text: errorMessage, comment: "failed with: \(String(reflecting: request)) to \(url)")
                    }
                    return dict
                }
            }
            print("API: DEBUG: \(String(describing: request.url)): Extracted response body: \(result)")
            completion(result)
        }
        task.resume()
        return task
    }
}


func debugInfo(for request: URLRequest) -> String {
    let target = "\(request.httpMethod ?? "«no method»") \(request.url?.absoluteString ?? "«no url»")"
    let headers = request.allHTTPHeaderFields?.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? "«nil headers»"
    let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) ?? String(reflecting: $0) }
        ??  "httpBody: \(String(reflecting: request.httpBody)) - httpBodyStream: \(String(reflecting: request.httpBodyStream))"
    return [target, headers, "", body].joined(separator: "\n")
}

func debugInfo(for response: HTTPURLResponse) -> String {
    let target = "\(response.statusCode) \(String(describing: response.url))"
    let headers = response.allHeaderFields.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    return [target, headers].joined(separator: "\n")
}
