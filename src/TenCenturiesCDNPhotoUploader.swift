import Foundation

class TenCenturiesCDNPhotoUploader: PhotoUploader, TenCenturiesService {
    let session: URLSession
    let authenticator: RequestAuthenticator
    init(session: URLSession, authenticator: RequestAuthenticator) {
        self.session = session
        self.authenticator = authenticator
    }

    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void) {
        let url = URL(string: "https://chat.10centuries.org/uploads.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let boundary = multipartBoundary(for: Date())
        request.setValue("multipart/form-data; boundary=\"\(boundary)\"", forHTTPHeaderField: "Content-Type")
        request.httpBody = asMultipartEnclosure(photo, boundary: boundary)

        _ = send(request: request) { (result: Result<JSONDictionary>) in
            do {
                let dict = try result.unwrap()
                let isGood = try unpack(dict, "isGood") as String
                guard isGood == "Y" else {
                    let result = try? unpack(dict, "result") as String
                    let text = result ?? NSLocalizedString("Uploaded photo deemed no good by 10C CDN", comment: "error message")
                    completion(.failure(TenCenturiesError.api(code: -1, text: text, comment: "photo upload deemed NOT GOOD")))
                    return
                }

                guard let url = URL(string: try unpack(dict, "cdnurl")) else {
                    let urlParsingFailed = NSLocalizedString("Failed to parse uploaded photo's CDN URL", comment: "error message")
                    let error = TenCenturiesError.other(message: urlParsingFailed, info: dict["cdnurl"] as Any)
                    completion(.failure(error))
                    return
                }
                completion(.success(url))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func send(request unauthenticated: URLRequest, completion: @escaping (Result<JSONDictionary>) -> Void) -> URLSessionTask {
        let request = authenticator.authenticate(request: unauthenticated)
        let url = request.url!  // swiftlint:disable:this
        print("API: INFO: BEGIN \(String(describing: request.url)) \(request)")
        print("API: DEBUG: BEGIN:\n\(debugInfo(for: request))")
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
                    print("API: INFO: END \(url): "
                        + "\(response.statusCode): \(String(describing: data)) \(String(describing: error)) "
                        + "- RATELIMIT: \(limits.map { String(reflecting: $0) } ?? "(headers not found)")")
                    print("API: DEBUG: END: \(response)\n\(debugInfo(for: response))")

                    guard let data = data else {
                        throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                    }

                    guard error == nil else {
                        throw error!
                    }

                    let object = try JSONSerialization.jsonObject(with: data, options: [])
                    guard let dict = object as? JSONDictionary else {
                        throw TenCenturiesError.badResponse(url: url, data: data, comment: "body is not a dict")
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

    func asMultipartEnclosure(_ photo: Photo, boundary: String) -> Data {
        let crlf = "\r\n"
        let chunkHeader = crlf + "--\(boundary)" + crlf
            + "Content-Disposition: form-data; name=\"file\"; filename=\"\(photo.title)\"" + crlf
            + "Content-Transfer-Encoding: binary" + crlf
            + "Content-Type: \(photo.mime)" + crlf
            + crlf
        let chunkFooter = crlf + "--\(boundary)--" + crlf
        let enclosure = chunkHeader.data(using: .utf8)! + photo.data + chunkFooter.data(using: .utf8)!
        return enclosure
    }

    func multipartBoundary(for date: Date) -> String {
        let maybeTooLong = "com.jeremywsherman.Macchiato-" + String(describing: date.timeIntervalSince1970)
        let limit = maybeTooLong.index(maybeTooLong.startIndex, offsetBy: 70, limitedBy: maybeTooLong.endIndex)
        let boundary = limit.map({ maybeTooLong[maybeTooLong.startIndex ..< $0] }) ?? maybeTooLong
        return boundary
    }
}
