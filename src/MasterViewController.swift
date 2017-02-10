//
//  MasterViewController.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-08.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {
    private(set) var streams = [Stream]()
    private(set) var services: ServicePack?
    private(set) var identity = Identity()
    func configure(services: ServicePack, identity: Identity, streams: [Stream]) {
        self.services = services
        self.identity = identity
        self.streams = streams

        defaultToDisplayingFirstStreamIfNotCollapsed()
    }

    func defaultToDisplayingFirstStreamIfNotCollapsed() {
        guard let stream = streams.first else {
            print("MASTER: DEBUG: No streams: Nothing to display yet")
            return
        }
        guard isViewLoaded, let tableView = tableView else {
            print("MASTER: DEBUG: View not loaded, so nothing to display a stream in.")
            return
        }
        guard let streamViewController = streamViewController else {
            print("MASTER: DEBUG: Split view controller is only displaying the master view, so let's not clobber that.")
            return
        }

        print("MASTER: DEBUG: Defaulting to displaying first stream in", streamViewController)
        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: true, scrollPosition: .top)
        // Programmatic |selectRow| does not trigger any associated |selection| segues.
        configure(streamViewController, toDisplay: stream)

        if traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .compact)) {
            print("COLLAPSING - NOT! PSYCH!")
            // It seems we need both of these. Yay for double-stacked navcons.
            streamViewController.navigationController?.popViewController(animated: false)
            navigationController?.popViewController(animated: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Streams", comment: "view title")

        defaultToDisplayingFirstStreamIfNotCollapsed()
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
    enum Segue: String {
        case showDetail = "showDetail"
        case showSettings = "ShowSettings"
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if prepareForShowDetail(segue: segue) { return }
        if prepareForShowSettings(segue: segue) { return }
        super.prepare(for: segue, sender: sender)
    }

    func prepareForShowDetail(segue: UIStoryboardSegue) -> Bool {
        guard segue.identifier == Segue.showDetail.rawValue else { return false }

        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            print("\(#function): DEBUG: no selection")
            return true
        }

        guard let controller = (segue.destination as? UINavigationController)?.topViewController as? StreamViewController else {
            print("failed out with template goop")
            return true
        }

        let stream = streams[indexPath.row]
        configure(controller, toDisplay: stream)
        return true
    }

    func configure(_ controller: StreamViewController, toDisplay stream: Stream) {
        guard let services = self.services else { return }

        controller.configure(stream: stream, postRepository: services.postRepository, identity: identity)
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
        print("MASTERVC(", self, "): INFO: Prepared stream VC", controller, "to display stream viewing:", stream.view)
    }

    func prepareForShowSettings(segue: UIStoryboardSegue) -> Bool {
        guard segue.identifier == Segue.showSettings.rawValue else { return false }
        guard let settings = (segue.destination as? UINavigationController)?.topViewController as? SettingsViewController else {
            print("destination not as expected: \(segue.destination)")
            return true
        }
        guard let services = self.services else {
            print("no services: not configured!")
            return true
        }

        settings.configure(sessionManager: services.sessionManager)
        print("MASTERVC(", self, "): INFO: Prepared settings VC", settings, "for display")
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
