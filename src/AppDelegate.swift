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
        services = ServicePack(
            postRepository: TenCenturiesPostRepository(session: session))
        super.init()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        splitViewController?.delegate = self
        streamViewController?.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        masterViewController?.streams = [Stream.global]
        masterViewController?.services = services
        return true
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
