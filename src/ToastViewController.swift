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

    // Could give https://github.com/KrauseFx/TSMessages a go later.
    DispatchQueue.main.async {
        let toaster = ToastViewController(title: title)

        var frame = UIScreen.main.bounds
        frame.size.height = CGFloat.infinity

        let window = UIWindow(frame:
            CGRect(
                origin: CGPoint(
                    x: 0,
                    y: UIApplication.shared.statusBarFrame.maxY),
                size: CGSize(
                    width: frame.size.width,
                    height: toaster.view.sizeThatFits(frame.size).height)))
        window.rootViewController = toaster
        window.windowLevel = UIWindowLevelAlert
        window.screen = UIScreen.main
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
