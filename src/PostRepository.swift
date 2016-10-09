import Foundation

protocol PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void)
}

class FakePostRepository: PostRepository {
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        completion(.success((0 ..< 10).map { _ in Post.makeFake() }))
    }
}

enum TenCenturiesError: Error {
    case notHTTP(url: URL)
    case badResponse(url: URL, data: Data?, comment: String)
    case parseError(url: URL, object: Any, comment: String)
    case missingField(field: String, object: JDict)
    case badFieldType(field: String, expected: Any, found: Any, in: JDict)
    /// The backend sent us a `{ meta: { code: Int, text: String }, data: false }` response.
    case api(code: Int, text: String, comment: String)
}

typealias JDict = [String: Any]

class TenCenturiesPostRepository: PostRepository {
    let session: URLSession
    init(session: URLSession) {
        self.session = session
    }

    // (@jeremy-w/2016-10-09)TODO: Handle since_id, prefix new posts
    func find(stream: Stream, since: Post?, completion: @escaping (Result<[Post]>) -> Void) {
        let url = URL(string: "https://api.10centuries.org/content/blurbs/global")!
        print("API: INFO: BEGIN \(url)")
        let task = session.dataTask(with: url) { (data, response, error) in
            let result = Result.of { () throws -> [Post] in do {
                guard let response = response as? HTTPURLResponse else {
                    throw TenCenturiesError.notHTTP(url: url)
                }
                print("API: INFO: END \(url): \(response.statusCode): \(data) \(error)")

                guard let data = data else {
                    throw TenCenturiesError.badResponse(url: url, data: nil, comment: "no data received")
                }

                guard error == nil else {
                    throw error!
                }

                let object = try JSONSerialization.jsonObject(with: data, options: [])
//                print("API: VDEBUG: \(url): \(String(reflecting: object))")

                guard let dict = object as? [String: Any]
                , let body = dict["data"] as? [[String: Any]]
                else {
                    throw TenCenturiesError.badResponse(url: url, data: data, comment: "bogus object in body")
                }
                return try body.map { post in
                    // (@jeremy-w/2016-10-08)FIXME: How to display edited_unix, too?
                    let accounts = try unpack(post, "account") as [JDict]
                    let account = accounts.first ?? ["username": "«unknown»"]
                    return Post(
                        id: String(describing: try unpack(post, "id") as Any),
                        author: try unpack(account, "username"),
                        date: Date(timeIntervalSince1970: try unpack(post, "created_unix")),
                        content: try unpack(unpack(post, "content"), "text"))
                }
            }}
            print("API: DEBUG: \(url): Result: \(result)")
            completion(result)
        }
        task.resume()
    }
}

func unpack<T>(_ obj: JDict, _ field: String) throws -> T {
    guard let value = obj[field] else {
        throw TenCenturiesError.missingField(field: field, object: obj)
    }

    guard let cast = value as? T else {
        throw TenCenturiesError.badFieldType(field: field, expected: T.self, found: value, in: obj)
    }

    return cast
}


let notYetImplemented = NSError(domain: "notyetimplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not Yet Implemented"])
