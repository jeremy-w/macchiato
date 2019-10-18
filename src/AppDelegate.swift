//
//  AppDelegate.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-08.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    var services: ServicePack
    var session: URLSession

    override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        session = URLSession(configuration: configuration)

        services = ServicePack.connectingTenCenturies(session: session)
        super.init()
        beginUpdatingIfCurrentUserAccountChanges()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return didFinishLaunching(ignoreTestMode: false)
    }

    func didFinishLaunching(ignoreTestMode: Bool) -> Bool {
        guard ignoreTestMode || NSClassFromString("XCTestCase") == nil else {
            print("Acting as test host: Bailing out of app-launch behaviors")
            return true
        }

        wireUpUIPostLaunch()
        confirmCurrentAccount()
        return true
    }

    func confirmCurrentAccount() {
        services.sessionManager.destroySessionIfExpired { result in
            print("AppDelegate.didFinishLaunching: Finished expired token check result=\(String(describing: result)). We may need to update UI more proactively on token change in future.")
            guard  let account = result else { return }

            self.identity.update(account: account)
        }
    }

    func wireUpUIPostLaunch() {
        splitViewController?.delegate = self
        streamViewController?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        configureMasterViewController()
    }


    // MARK: - Tracks user's identity
    let identity = Identity()
    var loggedInUserDidChangeListener: Any?
    func beginUpdatingIfCurrentUserAccountChanges() {
        print("APP: DEBUG: Now listening for user account changes.")
        whenLoggedInUserChanges(then: { [weak self] in
            print("APP: INFO: Logged-in user changed; will update identity.")
            guard let my = self else { return }

            my.confirmCurrentAccount()
        })
    }

    func whenLoggedInUserChanges(then call: @escaping () -> Void) {
        loggedInUserDidChangeListener = NotificationCenter.default.addObserver(
            forName: .loggedInAccountDidChange,
            object: services.sessionManager,
            queue: OperationQueue.main) { _ in
                call()
        }
    }


    // MARK: - Wires up the UI
    func configureMasterViewController() {
        guard let master = masterViewController else { return }

        let allStreams = [
            Stream.View.global,
            Stream.View.home,
//            Stream.View.starters,  // 2019-10-17: dead
            Stream.View.mentions,
            Stream.View.interactions,

            /*
             Omit "Private" stream until DMs are supported.

             See:

             - [Streams: Remove useless "Private" stream #122](https://gitlab.com/jeremy-w/macchiato/issues/122)
             - [Direct Messages: View & Post To #47](https://gitlab.com/jeremy-w/macchiato/issues/47)
             */
            // Stream.View.private_,

//            Stream.View.pinned,  // 2019-10-17: dead
//            Stream.View.starred,  // 2019-10-17: dead
            ].map { Stream(view: $0) }
        master.configure(services: services, identity: identity, streams: allStreams)
    }

    var splitViewController: UISplitViewController? {
        return window?.rootViewController as? UISplitViewController
    }

    var streamViewController: StreamViewController? {
        guard let navcon = splitViewController?.viewControllers.last as? UINavigationController else { return nil }
        return navcon.topViewController as? StreamViewController
    }

    var masterViewController: MasterViewController? {
        guard let navcon = splitViewController?.viewControllers.first as? UINavigationController else { return nil }
        return navcon.viewControllers.first as? MasterViewController
    }


    // MARK: - Split view
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
        ) -> Bool
    {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? StreamViewController else { return false }
        if topAsDetailController.stream == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        } else if !(masterViewController?.hasUserEverSelectedAStream ?? false) {
            // No row selected - we must have just launched.
            //
            // I didn't see a good way to detect when both views were shown for real
            // and we should treat it as if they selected and wanted to view something,
            // so we'll end up collapsing back to just the master view on rotate to portrait
            // until they legit select a row.
            return true
        }
        return false
    }
}


extension AppDelegate: ComposePostViewControllerDelegate {
    func uploadImage(
        for controller: ComposePostViewController,
        sender: UIButton,
        then continuation: @escaping ((title: String, href: URL)?) -> Void
    ) {
        let provider: PhotoProvider = ImagePickerPhotoProvider(controller: controller, sender: sender)
        provider.requestOne { [weak self] photo in
            self?.didReceivePhoto(photo, from: provider, continue: continuation)
        }
    }

    func didReceivePhoto(_ photo: Photo?, from provider: PhotoProvider, continue continuation: @escaping ((title: String, href: URL)?) -> Void) {
        print("COMPOSER/IMAGE: INFO: Image provider", provider, "gave photo:", photo as Any)
        guard let photo = photo else {
            continuation(nil)
            return
        }

        services.photoUploader.upload(photo) { [weak self] result in
            self?.didUpload(photo: photo, result: result, continue: continuation)
        }
    }

    func didUpload(photo: Photo, result: Result<URL>, continue continuation: @escaping ((title: String, href: URL)?) -> Void) {
        print("COMPOSER/IMAGE: INFO: Uploading photo", photo, "had result:", result)
        let info: (title: String, href: URL)?
        do {
            let location = try result.unwrap()
            info = (title: photo.title, href: location)
        } catch {
            toast(error: error, prefix: NSLocalizedString("Photo Upload Failed", comment: "toast error prefix"))
            info = nil
        }
        continuation(info)
    }
}
