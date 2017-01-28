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
        identity = Identity(accountRepository: services.accountRepository)
        super.init()
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
        identity.update()
        return true
    }

    func wireUpUIPostLaunch() {
        splitViewController?.delegate = self
        streamViewController?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        configureMasterViewController()
    }


    // MARK: - Tracks user's identity
    let identity: Identity
    var loggedInUserDidChangeListener: Any?
    func beginFetchingCurrentUserAccount() {
        whenLoggedInUserChanges(then: { [weak self] in self?.identity.update() })
        identity.update()
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

        master.services = services
        master.streams = [
            Stream.View.global,
            Stream.View.home,
            Stream.View.starters,
            Stream.View.mentions,
            Stream.View.interactions,
            Stream.View.private_,
            Stream.View.pinned,
            Stream.View.starred,
            ].map { Stream(view: $0) }
//        master.currentUser = currentUser
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
        }
        return false
    }
}
