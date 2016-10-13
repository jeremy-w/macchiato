//
//  MasterViewController.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-08.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {
    var streams = [Stream]()
    var services: ServicePack?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Streams", comment: "view title")
    }

    var streamViewController: StreamViewController? {
        return (splitViewController?.viewControllers.last as? UINavigationController)?.topViewController as? StreamViewController
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let isCollapsed = self.splitViewController?.isCollapsed {
            self.clearsSelectionOnViewWillAppear = isCollapsed
        }
    }


    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if prepareForShowDetail(segue: segue) { return }
        if prepareForShowSettings(segue: segue) { return }
        super.prepare(for: segue, sender: sender)
    }

    func prepareForShowDetail(segue: UIStoryboardSegue) -> Bool {
        guard segue.identifier == "showDetail" else { return false }

        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            print("\(#function): DEBUG: no selection")
            return true
        }

        guard let controller = (segue.destination as? UINavigationController)?.topViewController as? StreamViewController else {
            print("failed out with template goop")
            return true
        }

        guard let services = self.services else { return true }

        let stream = streams[indexPath.row]
        controller.configure(stream: stream, postRepository: services.postRepository)
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        return true
    }

    func prepareForShowSettings(segue: UIStoryboardSegue) -> Bool {
        guard segue.identifier == "ShowSettings" else { return false }
        guard let settings = (segue.destination as? UINavigationController)?.topViewController as? SettingsViewController else {
            print("destination not as expected: \(segue.destination)")
            return true
        }
        guard let services = self.services else {
            print("no services: not configured!")
            return true
        }

        settings.configure(sessionManager: services.sessionManager)
        return true
    }

    @IBAction func unwindToMaster(_ segue: UIStoryboardSegue) {
        return
    }


    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streams.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = streams[indexPath.row].name
        return cell
    }
}
