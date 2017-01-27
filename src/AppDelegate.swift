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
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        guard NSClassFromString("XCTestCase") == nil else {
            print("Acting as test host: Bailing out of app-launch behaviors")
            return true
        }
        splitViewController?.delegate = self
        streamViewController?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        configureMasterViewController()
        beginFetchingCurrentUserAccount()
        return true
    }


    // MARK: - Tracks the current user's account info
    var currentUser: Account? {
        didSet {
            print("ACCOUNT: INFO: Current user did change to:", currentUser as Any)
            DispatchQueue.main.async { self.pushCurrentUserToViewControllers() }
        }
    }
    var loggedInUserDidChangeListener: Any?

    func beginFetchingCurrentUserAccount() {
        whenLoggedInUserChanges(then: { [weak self] in self?.updateCurrentUser() })
        updateCurrentUser()
    }

    func whenLoggedInUserChanges(then call: @escaping () -> Void) {
        loggedInUserDidChangeListener = NotificationCenter.default.addObserver(
            forName: .loggedInAccountDidChange,
            object: services.sessionManager,
            queue: OperationQueue.main) { _ in
                call()
        }
    }

    func updateCurrentUser() {
        guard services.sessionManager.loggedInAccountName != nil else {
            currentUser = nil
            return
        }

        services.accountRepository.account(id: "me") { (result) in
            guard case let .success(user) = result else { return }

            self.currentUser = user
        }
    }

    func pushCurrentUserToViewControllers() {
        // (jeremy-w/2017-01-20)FIXME: This direct push of |currentUser| changes is kind of questionable.
        // Should we throw another notification?
        masterViewController?.currentUser = currentUser
        if let navcon = splitViewController?.viewControllers.last as? UINavigationController {
            for vc in navcon.viewControllers {
                if let streamVC = vc as? StreamViewController {
                    streamVC.currentUser = currentUser
                }
            }
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
        master.currentUser = currentUser
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
