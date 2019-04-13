import XCTest
@testable import Macchiato

class PostParsing: XCTestCase {
    let subject = TenCenturiesPostRepository(session: anySession, authenticator: DummyRequestAuthenticator())

    func testParsingThreadInfoForAThreadedPost() {
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

    func testParsingMentions() {
        do {
            let post = try subject.parsePost(from: capturedPostWithThreadInfo)
            let expected = [
                Post.Mention(name: "skematica", id: "12", current: "skematica"),
                Post.Mention(name: "larand", id: "26", current: "larand"),
            ]
            XCTAssertEqual(post.mentions.count, expected.count, "count of mentions doesn't match")
            for (i, (actual, intended)) in zip(post.mentions, expected).enumerated() {
                XCTAssertEqual(actual, intended, "bogus mention parsing at index \(i)")
            }
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    func testParsingAccount() {
        do {
            let post = try subject.parsePost(from: capturedPostWithThreadInfo)
            XCTAssertEqual(post.author, "gtwilson", "author")
            XCTAssertEqual(post.account.id, "91", "id")
            XCTAssertEqual(post.account.avatarURL, URL(string: "https://cdn.10centuries.org/p7E6pB/6bce7312df48d9061391d17301b04192.jpg")!, "avatar URL")
            XCTAssertEqual(post.account.counts, [
                "following": 38,
                "followers": 22,
                "stars": 77,
                "tinyposts": 494,
                "microposts": 1065,
                "shortposts": 261,
                "longposts": 4,
                "blogposts": 4,
                "podcasts": 0], "counts")
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    func testParsingPostWithVisibilityNoneSkipsPost() {
        guard let exampleHiddenPost = (try? unjson(string: "{\n"
            + "   \"id\": 111724,\n"
            + "   \"is_visible\": false,\n"
            + "   \"is_muted\": false,\n"
            + "   \"is_deleted\": false\n"
            + "}")) as? JSONDictionary else
        {
            return XCTFail("failed test setup: not a JSONDictionary")
        }

        var didThrow = false
        do {
            let post = try subject.parsePost(from: exampleHiddenPost)
            XCTAssertEqual(post.id, "111724", "post.id")
        } catch {
            didThrow = true
        }
        XCTAssertTrue(didThrow, "should have thrown an error rather than provide a useless post")
    }

    func testParsingPostsWithOneBogusPostStillReturnsTheGoodOnes() {
        let fakePosts = [capturedPostWithThreadInfo, ["bogus": "post"]]
        do {
            let parsedPosts = try subject.parsePosts(from: fakePosts)
            XCTAssertGreaterThanOrEqual(parsedPosts.count, 1, "should have at least passed through the good post; might also have a “something went wrong” placeholder for the bogus one")
        } catch {
            return XCTFail("failed to pass through the good posts: \(error)")
        }
    }

    var capturedPostWithThreadInfo: JSONDictionary {
        return try! unjson(string: """
            {
              "id": 78788,
              "parent_id": false,
              "title": "",
              "slug": "78788",
              "type": "post.micro",
              "privacy": "visibility.public",
              "guid": "1ea3ce889bb872499d339d572834f765aa1c8a27",
              "content": {
                "text": "@larand Well, he did manage to hit the moon eventually. \\n\\n\\/\\/ @skematica",
                "html": "<p><span class=\\"account\\" data-account-id=\\"26\\"><span class=\\"account\\" data-account-id=\\"26\\">@larand<\\/span><\\/span> Well, he did manage to hit the moon eventually.<\\/p><p>\\/\\/ <span class=\\"account\\" data-account-id=\\"12\\">@skematica<\\/span><\\/p>",
                "summary": false,
                "banner": false,
                "is_edited": false
              },
              "audio": false,
              "tags": false,
              "files": false,
              "urls": {
                "canonical_url": "\\/post\\/78788",
                "full_url": "10centuries.org\\/post\\/78788",
                "alt_url": "10centuries.org\\/78788",
                "is_https": true
              },
              "thread": {
                "thread_id": 78779,
                "reply_to": 78786,
                "is_selected": false
              },
              "mentions": [
                {
                  "id": 12,
                  "name": "@skematica",
                  "current": "@skematica"
                },
                {
                  "id": 26,
                  "name": "@larand",
                  "current": "@larand"
                }
              ],
              "account": [
                {
                  "id": 91,
                  "avatar_url": "\\/\\/cdn.10centuries.org\\/p7E6pB\\/6bce7312df48d9061391d17301b04192.jpg",
                  "username": "gtwilson",
                  "canonical_url": "https:\\/\\/10centuries.org\\/profile\\/gtwilson",
                  "podcast_rss": false,
                  "name": {
                    "first_name": "Tom",
                    "last_name": "Wilson",
                    "display": "Tom Wilson"
                  },
                  "counts": {
                    "following": 38,
                    "followers": 22,
                    "stars": 77,
                    "tinyposts": 494,
                    "microposts": 1065,
                    "shortposts": 261,
                    "longposts": 4,
                    "blogposts": 4,
                    "podcasts": 0
                  },
                  "description": {
                    "text": "Software developer. Husband. Wage slave.\\nhttp:\\/\\/eee-eye-eee.io",
                    "html": "<p>Software developer. Husband. Wage slave.<br \\/> <a target=\\"_blank\\" href=\\"http:\\/\\/eee-eye-eee.io\\">http:\\/\\/eee-eye-eee.io<\\/a><\\/p>"
                  },
                  "created_at": "2016-09-06T18:48:25Z",
                  "timezone": "US\\/Eastern",
                  "verified": {
                    "is_verified": false,
                    "url": ""
                  },
                  "annotations": false,
                  "cover_image": false,
                  "evangelist": false,
                  "follows_you": true,
                  "you_follow": true,
                  "is_muted": false,
                  "is_silenced": false
                }
              ],
              "channel": {
                "id": 1,
                "owner_id": false,
                "type": "channel.global",
                "privacy": "visibility.public",
                "guid": "d9ba5a8d768d0dbd9fc9c3ea4c8e183b2aa7336c",
                "created_at": "2015-08-01T00:00:00Z",
                "created_unix": 1438387200,
                "updated_at": "2015-08-01T00:00:00Z",
                "updated_unix": 1438387200
              },
              "client": {
                "hash": "a4e797c491b139358ab6d58acf7f11733102cc9c",
                "name": "Cappuccino"
              },
              "created_at": "2016-10-09T18:11:52Z",
              "created_unix": 1476036712,
              "publish_at": "2016-10-09T18:11:52Z",
              "publish_unix": 1476036712,
              "updated_at": "2016-10-09T18:11:52Z",
              "updated_unix": 1476036712,
              "expires_at": false,
              "expires_unix": false,
              "is_mention": false,
              "you_starred": false,
              "you_pinned": false,
              "you_reposted": false,
              "reposts": 0,
              "stars": false,
              "parent": false,
              "is_visible": true,
              "is_muted": false,
              "is_deleted": false
            }
            """) as! [String: Any]
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
