import Foundation

class Stream {
    let name: String
    let view: View
    var lastFetched: Date?
    var earliestFetched: Date?

    var posts: [Post]
    init(name: String, view: View, posts: [Post] = []) {
        self.name = name
        self.view = view
        self.posts = posts
        sortPosts()
    }

    convenience init(view: View, posts: [Post] = []) {
        self.init(name: view.localizedName, view: view, posts: posts)
    }

    // MARK: - Handles merging in new posts
    func replacePosts(with posts: [Post], fetchedAt date: Date) {
        self.posts = posts
        lastFetched = date
        sortPosts()

        // since_unix is relative to PUBLISHED date. See #79.
        // https://gitlab.com/jeremy-w/macchiato/issues/79
        let earliestInBatch = posts.map({ $0.date }).min()
        maybeUpdateEarliestFetched(with: earliestInBatch)
    }

    func maybeUpdateEarliestFetched(with date: Date?) {
        switch (earliestFetched, date) {
        case let (was?, now?):
            earliestFetched = min(was, now)

        case let (nil, now?):
            earliestFetched = now

        default:
            break
        }
    }

    func merge(posts merging: [Post], olderThan border: Date) {
        // (jeremy-w/2017-02-05)???: Should this be earliest updated, or created? Not sure what 10C feeds us.
        guard !merging.isEmpty, let earliestInBatch = merging.map({ $0.updated }).min() else {
            return
        }
        maybeUpdateEarliestFetched(with: earliestInBatch)

        var knownIDs: Set<String> = Set(merging.map({ $0.id }))
        posts = posts.filter { post -> Bool in
            let (didInsert, _) = knownIDs.insert(post.id)
            return didInsert
        }
        posts.append(contentsOf: merging)
        sortPosts()
    }

    func sortPosts() {
        // Sorting by `date` rather than `updated` leaves edited posts in their original place
        // in the timeline, which is what you want an edit to do, right?
        posts.sort(by: { $0.date > $1.date })
    }


    // MARK: - Knows about well-known streams
    static let global = Stream(view: .global, posts: (0 ..< 10).map { _ in Post.makeFake() })

    enum View: Equatable {
        case global
        case home
        case starters

        case mentions
        case interactions
        case private_

        case pinned
        case starred

        case thread(containing: String)

        var localizedName: String {
            switch self {
            case .global:
                return NSLocalizedString("Global", comment: "stream name")

            case .home:
                return NSLocalizedString("Home", comment: "stream name")

            case .starters:
                return NSLocalizedString("Starters", comment: "stream name")

            case .mentions:
                return NSLocalizedString("Mentions", comment: "stream name")

            case .interactions:
                return NSLocalizedString("Interactions", comment: "stream name")

            case .private_:
                return NSLocalizedString("Private", comment: "stream name")

            case .pinned:
                return NSLocalizedString("Pinned", comment: "stream name")

            case .starred:
                return NSLocalizedString("Starred", comment: "stream name")

            case let .thread(root):
                let format = NSLocalizedString("Thread for Post #%@", comment: "stream name - %@ is post ID")
                return String(format: format, root)
            }
        }
    }
}

func == (left: Stream.View, right: Stream.View) -> Bool {
    return left.localizedName == right.localizedName
}


extension Post {
    var threadStream: Stream {
        return Stream(view: .thread(containing: id), posts: [self])
    }
}
