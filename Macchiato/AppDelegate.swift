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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        guard let window = window else {
            preconditionFailure("failed to connect or load window")
        }
        // Override point for customization after application launch.
        guard let splitViewController = window.rootViewController as? UISplitViewController
        , let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1]
            as? UINavigationController else {
            preconditionFailure("expected to find a navigation controller in my splitview")
        }
        navigationController.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        return true
    }


    // MARK: - Split view
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
        ) -> Bool
    {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
}

