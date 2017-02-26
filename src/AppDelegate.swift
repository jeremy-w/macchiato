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
        session = URLSession(configuration: URLSessionConfiguration.default)
        services = ServicePack.connectingTenCenturies(session: session)
        super.init()
        beginFetchingCurrentUserAccount()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return didFinishLaunching(ignoreTestMode: false)
    }

    func didFinishLaunching(ignoreTestMode: Bool) -> Bool {
        guard ignoreTestMode || NSClassFromString("XCTestCase") == nil else {
            print("Acting as test host: Bailing out of app-launch behaviors")
            return true
        }

        wireUpUIPostLaunch()
        identity.update(using: services.accountRepository)
        return true
    }

    func wireUpUIPostLaunch() {
        splitViewController?.delegate = self
        streamViewController?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        configureMasterViewController()
    }


    // MARK: - Tracks user's identity
    let identity = Identity()
    var loggedInUserDidChangeListener: Any?
    func beginFetchingCurrentUserAccount() {
        print("APP: DEBUG: Now listening for user account changes.")
        whenLoggedInUserChanges(then: { [weak self] in
            print("APP: INFO: Logged-in user changed; will update identity.")
            guard let my = self else { return }

            my.identity.update(using: my.services.accountRepository)
        })
        identity.update(using: services.accountRepository)
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
            Stream.View.starters,
            Stream.View.mentions,
            Stream.View.interactions,
            Stream.View.private_,
            Stream.View.pinned,
            Stream.View.starred,
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
        guard let photo = photo else { return }

        services.photoUploader.upload(photo) { [weak self] result in
            self?.didUpload(photo: photo, result: result, continue: continuation)
        }
    }

    func didUpload(photo: Photo, result: Result<URL>, continue continuation: @escaping ((title: String, href: URL)?) -> Void) {
        print("COMPOSER/IMAGE: INFO: Uploading photo", photo, "had result:", result)
        do {
            let location = try result.unwrap()
            continuation((title: photo.title, href: location))
        } catch {
            toast(error: error, prefix: NSLocalizedString("Photo Upload Failed", comment: "toast error prefix"))
        }
    }
}
