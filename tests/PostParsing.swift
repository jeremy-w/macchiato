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

            XCTAssertEqual(thread.root, "a7a4b37c-2a87-c758-4d5a-6aa5920eaf07", "failed to correctly parse .thread.guid aka thread.root")
            // (jeremy-w/2019-04-12)TODO: To handle decentralization, this will need to become a URL.
            XCTAssertEqual(thread.replyTo, "https://phoneboy.info/note/a7a4b37c-2a87-c758-4d5a-6aa5920eaf07", "failed to correctly parse .reply_to")
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    func testParsingMentions() {
        do {
            let post = try subject.parsePost(from: capturedPostWithThreadInfo)
            let expected = [
                Post.Mention(name: "phoneboy", id: "15e9a17d-9407-11e8-bbd7-54ee758049c3", current: "phoneboy", isYou: false),
            ]
            XCTAssertEqual(post.mentions.count, expected.count, "count of mentions doesn't match mentions=\(post.mentions)")
            for (i, (actual, intended)) in zip(post.mentions, expected).enumerated() {
                XCTAssertEqual(actual, intended, "bogus mention parsing at index \(i)")
            }
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    func testParsingAccount() {
        do {
            let rawAccount = try unpack(capturedPostWithThreadInfo, "persona") as JSONDictionary
            let account = try TenCenturiesAccountRepository.parseAccount(from: rawAccount)
            XCTAssertEqual(account.username, "matigo", ".persona.as should become post.author aka post.account.username")
            XCTAssertEqual(account.id, "07d2f4ec-545f-11e8-99a0-54ee758049c3", ".guid should become post.id")
            XCTAssertEqual(account.avatarURL, URL(string: "https://matigo.ca/avatars/jason_fox_box.jpg")!, ".persona.avatar should become post.account.avatarURL")
            /* (jeremy-w/2019-04-12)TODO: Delete Account.counts field */
            XCTAssertEqual(account.counts, [:], "counts does not exist in 10Cv5")
        } catch {
            return XCTFail("parsing failed completely: \(error)")
        }
    }

    /*
     meta =     {
         source =         {
             author = 0;
             summary = 0;
             title = "Cairo Throw";
             url = "https://www.areaware.com/collections/susan-kare/products/cairo-throw-green-pink";
         };
     };
     */
    func testParsingQuotePostSource() {
        do {
            let examplePost = """
{
  "guid": "3f705a8f-5ab8-7723-1784-62256032d98a",
  "type": "post.bookmark",
  "privacy": "visibility.public",
  "canonical_url": "https://axodys.10centuries.org/bookmark/3f705a8f-5ab8-7723-1784-62256032d98a",
  "reply_to": false,
  "title": false,
  "content": "<blockquote>  <p>The original emoji, Cairo was a typeface designed by Susan Kare in 1984 for the first Macintosh operating system. Taking its name from the hieroglyphics of ancient Egypt, each symbol was drawn by hand using the bitmap grid. A few notable symbols lived on into later operating systems including the cursor and watch.</p>     <p>Kare designed this woven blanket for the Jacquard loom, an early example of computer-controlled machinery, operated with punched cards and invented by Joseph Jacquard in 1801.</p> </blockquote><p>I discovered this blanket in Stephen Hackett's Instagram stories and was immediately smitten. It would go great on the wall of my office, but at $135 it's well outside my decorating budget.</p>",
  "text": "> The original emoji, Cairo was a typeface designed by Susan Kare in 1984 for the first Macintosh operating system. Taking its name from the hieroglyphics of ancient Egypt, each symbol was drawn by hand using the bitmap grid. A few notable symbols lived on into later operating systems including the cursor and watch.\\n\\n> Kare designed this woven blanket for the Jacquard loom, an early example of computer-controlled machinery, operated with punched cards and invented by Joseph Jacquard in 1801.\\n\\nI discovered this blanket in Stephen Hackett's Instagram stories and was immediately smitten. It would go great on the wall of my office, but at $135 it's well outside my decorating budget.",
  "meta": {
    "source": {
      "url": "https://www.areaware.com/collections/susan-kare/products/cairo-throw-green-pink",
      "title": "Cairo Throw",
      "summary": false,
      "author": false
    }
  },
  "tags": false,
  "mentions": false,
  "persona": {
    "guid": "17b05554-22e9-65f5-dd62-14b3c692ed53",
    "as": "@axodys",
    "name": "Jason",
    "avatar": "https://axodys.10centuries.org/avatars/axodys.png",
    "pin": "pin.none",
    "you_follow": false,
    "is_muted": false,
    "is_starred": false,
    "is_blocked": false,
    "is_you": false,
    "profile_url": "https://axodys.10centuries.org/17b05554-22e9-65f5-dd62-14b3c692ed53/profile"
  },
  "attributes": {
    "pin": "pin.none",
    "starred": true,
    "muted": false,
    "points": 0
  },
  "publish_at": "2020-02-11T05:47:00Z",
  "publish_unix": 1581400020,
  "expires_at": false,
  "expires_unix": false,
  "updated_at": "2020-02-11T05:54:15Z",
  "updated_unix": 1581400455
}
"""
            let asDict = try! unjson(string: examplePost) as! JSONDictionary

            let post = try subject.parsePost(from: asDict)

            XCTAssertNotNil(post.source)
            guard let source = post.source else { return }

            XCTAssertNil(source.author)
            XCTAssertNil(source.summary)
            XCTAssertEqual(source.title, "Cairo Throw")
            XCTAssertEqual(source.urlString, "https://www.areaware.com/collections/susan-kare/products/cairo-throw-green-pink")
            XCTAssertEqual(source.url, URL(string: "https://www.areaware.com/collections/susan-kare/products/cairo-throw-green-pink")!)
        }  catch {
            return XCTFail("failed: \(error)")
        }
    }

    func testParsingPostWithVisibilityNoneSkipsPost() {
        // (jeremy-w/2019-04-12)FIXME: Needs updating for v5
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
            XCTAssertGreaterThanOrEqual(parsedPosts.count, 1, "should have at least passed through the good post; might also have a ???something went wrong??? placeholder for the bogus one")
        } catch {
            return XCTFail("failed to pass through the good posts: \(error)")
        }
    }

    func testParsingPostId() {
        let result = Result.of { return try subject.parsePost(from: capturedPostWithThreadInfo) }
        guard case let .success(post) = result else {
            return XCTFail("parsing failed with error: \(result)")
        }
        XCTAssertEqual(post.id, "ffd9955a-9b51-d2cd-bc53-4d70673f8e3a", "should treat .guid as post.id")
    }

    func testParsingMarkdown() {
        do {
            let post = try subject.parsePost(from: exampleLoggedOutPost)
            XCTAssertEqual(post.content, "@larand cool. Let me know if there\u{2019}s anything not quite right. There will be more updates rolling out in about 11 hours.")
        } catch {
            return XCTFail("parsing failed: \(error)")
        }
    }

    func testParsingClientName() {
        do {
            let clientName = try subject.parseClientName(from: capturedPostWithThreadInfo)
            XCTAssertEqual(clientName, "Default Client")
        } catch {
            return XCTFail("parsing failed: \(error)")
        }
    }

    func testParsingGeo() {
        let geoJsonString = "{\"meta\":{\"geo\":{\"longitude\":false,\"latitude\":false,\"altitude\":false,\"description\":\"@Toys R Us\"}}}"
        let geoDict = try! unjson(string: geoJsonString) as! JSONDictionary
        let geo = subject.parseGeo(from: geoDict)
        XCTAssertEqual(geo, Post.Geo(name: "@Toys R Us", latitude: nil, longitude: nil, altitude: nil))
    }

    func testParsingTitle() {
        let result = Result.of { return try subject.parsePost(from: capturedPostWithThreadInfo) }
        guard case let .success(post) = result else {
            return XCTFail("parsing failed with error: \(result)")
        }
        XCTAssertEqual(post.title, "either a title or boolean false")
    }

    var capturedPostWithThreadInfo: JSONDictionary {
        /*
         This is the result of:
                curl -H'accept: application/json' https://matigo.ca/api/post/ffd9955a-9b51-d2cd-bc53-4d70673f8e3a | jq .data[0]

         Found by munging the canonical URL of:
                https://matigo.ca/note/ffd9955a-9b51-d2cd-bc53-4d70673f8e3a

         from thread:
                https://nice.social/api/posts/ffd9955a-9b51-d2cd-bc53-4d70673f8e3a/thread?simple=Y
         */
        return try! unjson(string: """
            {
             "guid": "ffd9955a-9b51-d2cd-bc53-4d70673f8e3a",
             "type": "post.note",
             "thread": {
               "guid": "a7a4b37c-2a87-c758-4d5a-6aa5920eaf07",
               "count": 4
             },
             "privacy": "visibility.public",
             "persona": {
               "guid": "07d2f4ec-545f-11e8-99a0-54ee758049c3",
               "as": "@matigo",
               "name": "Jason",
               "avatar": "https://matigo.ca/avatars/jason_fox_box.jpg",
               "follow": {
                 "url": "https://matigo.ca/feeds/matigo.json",
                 "rss": "https://matigo.ca/feeds/matigo.xml"
               },
               "is_active": true,
               "is_you": false,
               "profile_url": "https://matigo.ca/profile/matigo",
               "created_at": "2012-08-01T00:00:00Z",
               "created_unix": 1343779200,
               "updated_at": "2018-05-17T19:07:26Z",
               "updated_unix": 1526584046
             },
             "title": "either a title or boolean false",
             "content": "<p><span class=\\"account\\" data-guid=\\"15e9a17d-9407-11e8-bbd7-54ee758049c3\\">@phoneboy</span> you use it for your own site. That said, it's now an optional variable. If you do not pass a <code>persona_guid</code> or <code>channel_guid</code>, then the defaults associated with the Account (based on the Auth Token) will be used.</p> <p>All you need to pass when publishing now is:</p> <p><code>content</code>: what you want to say<br><code>post_type</code>: what is it (post.note, post.article, post.bookmark, post.quotation)</p>",
             "text": "@phoneboy you use it for your own site. That said, it's now an optional variable. If you do not pass a `persona_guid` or `channel_guid`, then the defaults associated with the Account (based on the Auth Token) will be used.\\n\\nAll you need to pass when publishing now is:\\n\\n`content`: what you want to say\\n`post_type`: what is it (post.note, post.article, post.bookmark, post.quotation)",
             "publish_at": "2019-04-12T14:04:25Z",
             "publish_unix": 1555077865,
             "expires_at": false,
             "expires_unix": false,
             "updated_at": "2019-04-12T14:04:25Z",
             "updated_unix": 1555077865,
             "meta": false,
             "tags": false,
             "mentions": {
               "guid": "15e9a17d-9407-11e8-bbd7-54ee758049c3",
               "as": "@phoneboy",
               "is_you": false
             },
             "canonical_url": "https://matigo.ca/note/ffd9955a-9b51-d2cd-bc53-4d70673f8e3a",
             "slug": "ffd9955a-9b51-d2cd-bc53-4d70673f8e3a",
             "reply_to": "https://phoneboy.info/note/a7a4b37c-2a87-c758-4d5a-6aa5920eaf07",
             "class": "h-entry p-in-reply-to",
             "attributes": {
               "pin": "pin.none",
               "starred": false,
               "muted": false,
               "points": 0
             },
             "channel": {
               "guid": "91c46924-5461-11e8-99a0-54ee758049c3",
               "name": "Matigo dot See, eh?",
               "type": "channel.site",
               "privacy": "visibility.public",
               "created_at": "2018-05-10T14:51:06Z",
               "created_unix": 1525963866,
               "updated_at": "2019-04-03T16:24:17Z",
               "updated_unix": 1554308657
             },
             "site": {
               "guid": "cc5346ea-9358-df5c-90ea-e27c343e4843",
               "name": "Matigo dot See, eh?",
               "description": "The Semi-Coherent Ramblings of a Canadian in Asia",
               "keywords": "matigo, 10C, v5, development, dev",
               "url": "https://matigo.ca"
             },
             "client": {
               "guid": "7677e4c0-545e-11e8-99a0-54ee758049c3",
               "name": "Default Client",
               "logo": "https://matigo.ca/images/default.png"
             },
             "can_edit": false
            }
            """) as! [String: Any]
    }

    /**
     Appears to omit: site, channel, client, attributes.
     */
    var exampleLoggedOutPost: JSONDictionary {
        return try! PropertyListSerialization.propertyList(from: """
        {
            "canonical_url" = "https://matigo.ca/note/dcca727e-6bd9-433c-1284-e989073bdc1c";
            content = "<p><span class=\\"account\\" data-guid=\\"0f3bca0a-5932-11e8-b49f-54ee758049c3\\">@larand</span> cool. Let me know if there\\U2019s anything not quite right. There will be more updates rolling out in about 11 hours.</p>";
            "expires_at" = 0;
            "expires_unix" = 0;
            guid = "dcca727e-6bd9-433c-1284-e989073bdc1c";
            mentions =     {
                as = "@larand";
                guid = "0f3bca0a-5932-11e8-b49f-54ee758049c3";
                "is_you" = 0;
            };
            meta = 0;
            persona =     {
                as = "@matigo";
                avatar = "https://matigo.ca/avatars/jason_fox_box.jpg";
                guid = "07d2f4ec-545f-11e8-99a0-54ee758049c3";
                "is_you" = 0;
                name = Jason;
                "profile_url" = "https://matigo.ca/07d2f4ec-545f-11e8-99a0-54ee758049c3/profile";
                "you_follow" = 0;
            };
            privacy = "visibility.public";
            "publish_at" = "2019-04-13T02:52:41Z";
            "publish_unix" = 1555123961;
            "reply_to" = "https://larryanderson.org/note/659c083b-c4b9-845c-e269-8d26b3abfe82";
            tags = 0;
            text = "@larand cool. Let me know if there\\U2019s anything not quite right. There will be more updates rolling out in about 11 hours.";
            title = 0;
            type = "post.note";
            "updated_at" = "2019-04-13T02:52:41Z";
            "updated_unix" = 1555123961;
        }
        """.data(using: .utf8)!, options: [], format: nil) as! JSONDictionary
    }
}

struct DummyRequestAuthenticator: RequestAuthenticator {
    var canAuthenticate = true

    func authenticate(request: URLRequest) -> URLRequest {
        return request
    }
}

let anySession = URLSession(configuration: URLSessionConfiguration.default)
let anyURL = URL(fileURLWithPath: "any test URL")

func unjson(string: String) throws -> Any {
    return try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: [])
}
