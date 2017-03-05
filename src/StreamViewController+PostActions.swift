import Foundation
import UIKit
import SafariServices

extension StreamViewController {
    // MARK: - Allows taking actions on posts
    @IBAction func longPressAction(sender: UILongPressGestureRecognizer) {
        let point = sender.location(in: view)
        presentPostActions(at: point)
    }

    func presentPostActions(at point: CGPoint) {
        guard let target = post(at: point) else {
            print("STREAMVC/", stream?.view as Any, ": ERROR: No post at long-press location. Unable to find context to show post actions.")
            return
        }

        let alert = makePostActionAlert(for: target, at: point)
        print("STREAMVC/", stream?.view as Any, ": INFO: Showing alert with", alert.actions.count, "actions for post:", target.id)
        present(alert, animated: true, completion: nil)
    }

    func makePostActionAlert(for post: Post, at point: CGPoint) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        func perform(_ action: PostAction) -> (UIAlertAction) -> Void {
            return { [weak self] _ in self?.take(action: action, on: post) }
        }

        if post.account.id == identity.account?.id {
            alert.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Delete", comment: "delete post action button title"),
                    style: .destructive,
                    handler: perform(.delete)))
        }

        for (title, action) in [
            (NSLocalizedString("Reply", comment: "button"), .reply),
            (post.you.starred
                ? NSLocalizedString("Unstar", comment: "button")
                : NSLocalizedString("Star", comment: "button"), .star),
            (post.you.pinned == nil
                ? NSLocalizedString("Pin", comment: "button")
                : NSLocalizedString("Edit Pin", comment: "button"), .pin(at: point)),
            (NSLocalizedString("Repost", comment: "button"), .repost),
            (((post.account.id == identity.account?.id)
                ? NSLocalizedString("Edit", comment: "button")
                : ""), .edit),
            (NSLocalizedString("View in WebView", comment: "button"), .webView),
        ] as [(String, PostAction)] {
            switch action {
            case .webView:
                break

            default:
                guard isLoggedIn else { continue }
            }

            guard !title.isEmpty else { continue }
            alert.addAction(UIAlertAction(title: title, style: .default, handler: perform(action)))
        }

        let cancel = makeCancelAction()
        alert.addAction(cancel)
        alert.preferredAction = cancel
        addPopoverLocationInfo(to: alert, at: point)
        return alert
    }

    func addPopoverLocationInfo(to alert: UIAlertController, at point: CGPoint) {
        guard let presenter = alert.popoverPresentationController
        , let tableView = tableView
        else {
            print("STREAMVC/", stream?.view as Any, ": WARNING: Unable to provide location info for popover: TableView is not loaded.")
            return
        }

        presenter.sourceView = tableView
        presenter.sourceRect = CGRect(origin: point, size: CGSize.zero)
    }

    func makeCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: "button"), style: .default, handler: nil)
    }

    func take(action: PostAction, on post: Post) {
        print("STREAMVC/", stream?.view as Any, ": INFO: Taking post action", action, "on post:", post.id)
        switch action {
        case .reply:
            composePost(as: .newReply(to: post))

        case .star:
            postRepository?.star(post: post) { result in
                do {
                    let _ = try result.unwrap()
                    guard let stream = self.stream
                    , let index = stream.posts.index(where: { $0.id == post.id }) else { return }
                    DispatchQueue.main.async {
                        stream.posts[index].you.starred = !stream.posts[index].you.starred
                        self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        toast(title: NSLocalizedString("Starred!", comment: "title"))
                    }
                } catch {
                    toast(error: error, prefix: NSLocalizedString("Starring Failed", comment: "title"))
                }
            }

        case let .pin(point):
            let followup = makePinAlert(for: post, at: point)
            present(followup, animated: true, completion: nil)

        case .repost:
            postRepository?.repost(post: post, completion: { (result) in
                guard let stream = self.stream
                , let index = stream.posts.index(where: { $0.id == post.id }) else { return }

                do {
                    let _ = try result.unwrap()
                    DispatchQueue.main.async {
                        stream.posts[index].you.reposted = true
                        self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        toast(title: NSLocalizedString("Reposted!", comment: "title"))
                    }
                } catch {
                    toast(error: error, prefix: NSLocalizedString("Repost Failed", comment: "title"))
                }
            })

        case .edit:
            // (jeremy-w/2017-02-05)FIXME: Use .updateReply if this is a reply (has a parentID).
            composePost(as: .update(post))

        case .delete:
            confirmBeforeDeleting(post)

        case .webView:
            displayInWebView(URL(string: "https://10centuries.org/post/\(post.id)")!)
        }
    }

    func composePost(as action: ComposePostAction) {
        performSegue(withIdentifier: Segue.createNewThread.rawValue, sender: action)
    }

    func displayInWebView(_ url: URL) {
        let webView = SFSafariViewController(url: url)
        present(webView, animated: true, completion: nil)
    }

    func makePinAlert(for post: Post, at point: CGPoint) -> UIAlertController {
        let alert = UIAlertController(title: NSLocalizedString("Pin With…", comment: "button"), message: nil, preferredStyle: .actionSheet)
        for color: Post.PinColor in [.black, .blue, .green, .orange, .yellow, .red] {
            alert.addAction(
                UIAlertAction(
                    title: String(describing: color).capitalized,
                    style: .default,
                    handler: { _ in self.pin(post: post, with: color) }))
        }

        if post.you.pinned != nil {
            alert.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Unpin", comment: "button"),
                    style: .destructive,
                    handler: { _ in self.pin(post: post, with: nil) }))
        }

        let cancel = makeCancelAction()
        alert.addAction(cancel)
        alert.preferredAction = cancel
        addPopoverLocationInfo(to: alert, at: point)
        return alert
    }

    func pin(post: Post, with color: Post.PinColor?) {
        guard let repo = self.postRepository else { return }
        repo.pin(post: post, color: color) { (result) in
            do {
                let posts = try result.unwrap()
                guard let post = posts.first, let stream = self.stream else { return }
                guard let index = stream.posts.index(where: { $0.id == post.id }) else { return }
                DispatchQueue.main.async {
                    stream.posts[index] = post
                    self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                    toast(title: NSLocalizedString("Pinned!", comment: "title"))
                }
            } catch {
                toast(error: error, prefix: NSLocalizedString("Pin Failed", comment: "title"))
            }
        }
    }

    func confirmBeforeDeleting(_ post: Post) {
        guard let postRepository = postRepository else {
            print("STREAMVC/", stream?.view as Any,
                  ": ERROR: Refusing to confirm delete post action when no postRepository around to carry it out on it")
            return
        }

        let messageFormat = NSLocalizedString(
            "Deletion cannot be undone. The post beginning, “%@” will be deleted forever.",
            comment: "alert message - %@ is snippet from post")

        let end = post.content.index(post.content.startIndex, offsetBy: 24, limitedBy: post.content.endIndex) ?? post.content.endIndex
        let snippet = post.content.substring(to: end)
        let message = String.localizedStringWithFormat(messageFormat, snippet)

        let alert = UIAlertController(title: NSLocalizedString("Delete Post?", comment: "alert title"), message: message, preferredStyle: .alert)
        alert.addAction(makeCancelAction())
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: "alert button title"), style: .destructive, handler: { (_) in
            postRepository.delete(post: post, completion: { (result) in
                do {
                    let _ = try result.unwrap()
                    toast(title: NSLocalizedString("Post Deleted", comment: "toast text"))
                } catch {
                    toast(error: error, prefix: NSLocalizedString("Delete Post Failed", comment: "toast error prefix"))
                }
            })
        }))
        present(alert, animated: true)
    }

    enum PostAction {
        case reply
        case star
        case pin(at: CGPoint)
        case repost
        case edit
        case delete
        case webView
    }
}
