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
    }

    convenience init(view: View, posts: [Post] = []) {
        self.init(name: view.localizedName, view: view, posts: posts)
    }

    // MARK: - Handles merging in new posts
    func replacePosts(with posts: [Post], fetchedAt date: Date) {
        self.posts = posts
        lastFetched = date

        let earliestInBatch = posts.map({ $0.updated }).min()
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
        posts.sort(by: { $0.updated > $1.updated })
    }


    // MARK: - Knows about well-known streams
    static let global = Stream(view: .global, posts: (0 ..< 10).map { _ in Post.makeFake() })

    enum View {
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


extension Post {
    var threadStream: Stream {
        return Stream(view: .thread(containing: id), posts: [self])
    }
}
