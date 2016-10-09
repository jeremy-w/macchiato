//
//  MasterViewController.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-08.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {
    var objects = [Any]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    var detailViewController: DetailViewController? {
        return (splitViewController?.viewControllers.last as? UINavigationController)?.topViewController as? DetailViewController
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let isCollapsed = self.splitViewController?.isCollapsed {
            self.clearsSelectionOnViewWillAppear = isCollapsed
        }
    }


    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            guard let indexPath = self.tableView.indexPathForSelectedRow else {
                return print("\(#function): DEBUG: no selection")
            }

            guard let object = objects[indexPath.row] as? NSDate
                , let controller = (segue.destination as? UINavigationController)?.topViewController as? DetailViewController else {
                    return print("failed out with template goop")
            }

            controller.detailItem = object
            controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }


    // MARK: - Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        cell.textLabel?.text = String(describing: objects[indexPath.row])
        return cell
    }
}
