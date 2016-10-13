//
//  ToastViewController.swift
//  Macchiato
//
//  Created by Jeremy on 2016-10-09.
//  Copyright © 2016 Jeremy W. Sherman. All rights reserved.
//

import UIKit

func toast(title: String) {
    print("TOAST: INFO: \(title)")
    DispatchQueue.main.async {
        let toaster = ToastViewController(title: title)
        let window = toaster.hostWindow(for: UIScreen.main, statusBarHeight: UIApplication.shared.statusBarFrame.maxY)

        window.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5)) {
            toaster.dismiss()
            window.isHidden = true
        }
    }
}

class ToastViewController: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: Bundle(for: ToastViewController.self))
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBOutlet var label: UILabel?
    override func viewDidLoad() {
        super.viewDidLoad()
        label?.text = title
    }

    @IBAction func dismissGestureAction(sender: UIPanGestureRecognizer) {
        print("DEBUG: TOAST: Dismiss gesture invoked")
        sender.view?.removeGestureRecognizer(sender)
        dismiss()
    }

    private var dismissing = false
    func dismiss() {
        guard !dismissing else { return }
        dismissing = true

        print("DEBUG: TOAST: Dismissing: \(title) from \(viewIfLoaded?.window)")
        guard let window = viewIfLoaded?.window else { return }

        window.isHidden = true
    }
}


extension ToastViewController {
    func hostWindow(for screen: UIScreen, statusBarHeight: CGFloat) -> UIWindow {
        var screenBounds = screen.bounds
        screenBounds.size.height = CGFloat.infinity

        let fittingSize = CGSize(width: screenBounds.size.width, height: view.sizeThatFits(screenBounds.size).height)
        let window = UIWindow(frame: CGRect(origin: CGPoint(x: 0, y: statusBarHeight), size: fittingSize))
        window.rootViewController = self
        window.windowLevel = UIWindowLevelAlert
        window.screen = screen
        return window
    }
}
