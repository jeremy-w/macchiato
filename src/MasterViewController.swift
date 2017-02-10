//
//  MasterViewController.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-08.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {
    var hasUserEverSelectedAStream = false

    private(set) var streams = [Stream]()
    private(set) var services: ServicePack?
    private(set) var identity = Identity()
    func configure(services: ServicePack, identity: Identity, streams: [Stream]) {
        self.services = services
        self.identity = identity
        self.streams = streams

        defaultToDisplayingFirstStream()
    }

    func defaultToDisplayingFirstStream() {
        guard let stream = streams.first else {
            print("MASTER: DEBUG: No streams: Nothing to display yet")
            return
        }
        guard let streamViewController = streamViewController else {
            print("MASTER: DEBUG: No stream view controller to configure, yet.")
            return
        }

        print("MASTER: DEBUG: Defaulting to displaying first stream", stream, "in", streamViewController)
        configure(streamViewController, toDisplay: stream)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Streams", comment: "view title")

        defaultToDisplayingFirstStream()
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

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard let segue = Segue(rawValue: identifier) else {
            return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }

        switch segue {
        case .showSettings:
            return true

        case .showDetail:
            return willSelectedStreamActuallyChange
        }
    }

    var willSelectedStreamActuallyChange: Bool {
        guard isViewLoaded, let tableView = tableView, let selected = tableView.indexPathForSelectedRow else { return false }

        // (jeremy-w/2016-02-10)BUG: Clobbers default selection made at launch
        //
        // AKA SplitViewControllers are a pain.
        //
        // This doesn't seem to catch this scenario:
        //
        // - Launch iPhone 6+ landscape, Global displayed
        // - Scroll Global down
        // - Rotate to Portrait, Master table displayed
        // - Tap Global again, expecting to pick up where you left off
        // - Instead find yourself back at the top.
        guard let streamViewController = streamViewController, let hasSelected = streamViewController.stream else { return true }

        let willSelect = stream(for: selected)
        return hasSelected.view != willSelect.view
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if prepareForShowDetail(segue: segue) { return }
        if prepareForShowSettings(segue: segue) { return }
        super.prepare(for: segue, sender: sender)
    }

    func prepareForShowDetail(segue: UIStoryboardSegue) -> Bool {
        guard segue.identifier == Segue.showDetail.rawValue else { return false }
        hasUserEverSelectedAStream = true

        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            print("\(#function): DEBUG: no selection")
            return true
        }

        guard let controller = (segue.destination as? UINavigationController)?.topViewController as? StreamViewController else {
            print("failed out with template goop")
            return true
        }

        configure(controller, toDisplay: stream(for: indexPath))
        return true
    }

    func stream(for indexPath: IndexPath) -> Stream {
        return streams[indexPath.row]
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
