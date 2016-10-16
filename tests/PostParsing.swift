import XCTest
@testable import Macchiato

class PostParsing: XCTestCase {
    let subject = TenCenturiesPostRepository(session: anySession, authenticator: DummyRequestAuthenticator())

    func testParsingThreadInfoForAThreadedPost() throws {
        do {
            let post = try subject.parsePost(from: capturedPostWithThreadInfo)
            guard let thread = post.thread else {
                return XCTFail("failed to parse any thread info from post")
            }

            XCTAssertEqual(thread.root, "78779", "failed to correctly parse threadID AKA root")
            XCTAssertEqual(thread.replyTo, "78786", "failed to correctly parse replyTo")
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    var capturedPostWithThreadInfo: [String: Any] {
        return try! unjson(string: "{\n  \"id\": 78788,\n  \"parent_id\": false,\n  \"title\": \"\",\n  \"slug\": \"78788\",\n  \"type\": \"post.micro\",\n  \"privacy\": \"visibility.public\",\n  \"guid\": \"1ea3ce889bb872499d339d572834f765aa1c8a27\",\n  \"content\": {\n    \"text\": \"@larand Well, he did manage to hit the moon eventually. \\n\\n\\/\\/ @skematica\",\n    \"html\": \"<p><span class=\\\"account\\\" data-account-id=\\\"26\\\"><span class=\\\"account\\\" data-account-id=\\\"26\\\">@larand<\\/span><\\/span> Well, he did manage to hit the moon eventually.<\\/p><p>\\/\\/ <span class=\\\"account\\\" data-account-id=\\\"12\\\">@skematica<\\/span><\\/p>\",\n    \"summary\": false,\n    \"banner\": false,\n    \"is_edited\": false\n  },\n  \"audio\": false,\n  \"tags\": false,\n  \"files\": false,\n  \"urls\": {\n    \"canonical_url\": \"\\/post\\/78788\",\n    \"full_url\": \"10centuries.org\\/post\\/78788\",\n    \"alt_url\": \"10centuries.org\\/78788\",\n    \"is_https\": true\n  },\n  \"thread\": {\n    \"thread_id\": 78779,\n    \"reply_to\": 78786,\n    \"is_selected\": false\n  },\n  \"mentions\": [\n    {\n      \"id\": 12,\n      \"name\": \"@skematica\",\n      \"current\": \"@skematica\"\n    },\n    {\n      \"id\": 26,\n      \"name\": \"@larand\",\n      \"current\": \"@larand\"\n    }\n  ],\n  \"account\": [\n    {\n      \"id\": 91,\n      \"avatar_url\": \"\\/\\/cdn.10centuries.org\\/p7E6pB\\/6bce7312df48d9061391d17301b04192.jpg\",\n      \"username\": \"gtwilson\",\n      \"canonical_url\": \"https:\\/\\/10centuries.org\\/profile\\/gtwilson\",\n      \"podcast_rss\": false,\n      \"name\": {\n        \"first_name\": \"Tom\",\n        \"last_name\": \"Wilson\",\n        \"display\": \"Tom Wilson\"\n      },\n      \"counts\": {\n        \"following\": 38,\n        \"followers\": 22,\n        \"stars\": 77,\n        \"tinyposts\": 494,\n        \"microposts\": 1065,\n        \"shortposts\": 261,\n        \"longposts\": 4,\n        \"blogposts\": 4,\n        \"podcasts\": 0\n      },\n      \"description\": {\n        \"text\": \"Software developer. Husband. Wage slave.\\nhttp:\\/\\/eee-eye-eee.io\",\n        \"html\": \"<p>Software developer. Husband. Wage slave.<br \\/> <a target=\\\"_blank\\\" href=\\\"http:\\/\\/eee-eye-eee.io\\\">http:\\/\\/eee-eye-eee.io<\\/a><\\/p>\"\n      },\n      \"created_at\": \"2016-09-06T18:48:25Z\",\n      \"timezone\": \"US\\/Eastern\",\n      \"verified\": {\n        \"is_verified\": false,\n        \"url\": \"\"\n      },\n      \"annotations\": false,\n      \"cover_image\": false,\n      \"evangelist\": false,\n      \"follows_you\": true,\n      \"you_follow\": true,\n      \"is_muted\": false,\n      \"is_silenced\": false\n    }\n  ],\n  \"channel\": {\n    \"id\": 1,\n    \"owner_id\": false,\n    \"type\": \"channel.global\",\n    \"privacy\": \"visibility.public\",\n    \"guid\": \"d9ba5a8d768d0dbd9fc9c3ea4c8e183b2aa7336c\",\n    \"created_at\": \"2015-08-01T00:00:00Z\",\n    \"created_unix\": 1438387200,\n    \"updated_at\": \"2015-08-01T00:00:00Z\",\n    \"updated_unix\": 1438387200\n  },\n  \"client\": {\n    \"hash\": \"a4e797c491b139358ab6d58acf7f11733102cc9c\",\n    \"name\": \"Cappuccino\"\n  },\n  \"created_at\": \"2016-10-09T18:11:52Z\",\n  \"created_unix\": 1476036712,\n  \"publish_at\": \"2016-10-09T18:11:52Z\",\n  \"publish_unix\": 1476036712,\n  \"updated_at\": \"2016-10-09T18:11:52Z\",\n  \"updated_unix\": 1476036712,\n  \"expires_at\": false,\n  \"expires_unix\": false,\n  \"is_mention\": false,\n  \"you_starred\": false,\n  \"you_pinned\": false,\n  \"you_reposted\": false,\n  \"reposts\": 0,\n  \"stars\": false,\n  \"parent\": false,\n  \"is_visible\": true,\n  \"is_muted\": false,\n  \"is_deleted\": false\n}") as! [String: Any]
    }
}

struct DummyRequestAuthenticator: RequestAuthenticator {
    func authenticate(request: URLRequest) -> URLRequest {
        return request
    }
}

let anySession = URLSession(configuration: URLSessionConfiguration.default)
let anyURL = URL(fileURLWithPath: "any test URL")

func unjson(string: String) throws -> Any {
    return try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: [])
}
