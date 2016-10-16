import Foundation

class Stream {
    let name: String
    let view: View

    var posts: [Post]
    init(name: String, view: View, posts: [Post] = []) {
        self.name = name
        self.view = view
        self.posts = posts
    }

    convenience init(view: View, posts: [Post] = []) {
        self.init(name: view.localizedName, view: view, posts: posts)
    }

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
