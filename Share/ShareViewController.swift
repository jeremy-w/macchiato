//
//  ShareViewController.swift
//  Share
//
//  Created by Jeremy W. Sherman on 2020-05-23.
//  Copyright © 2020 Jeremy W. Sherman. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices  // UTType*

/**
 System extension point for sharing.

 See: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
 */
class ShareViewController: SLComposeServiceViewController {

    override func presentationAnimationDidFinish() {
        logExtensionItems()
    }

    private func logExtensionItems() {
        guard let ctx = extensionContext else { return }
        guard let items = ctx.inputItems as? [NSExtensionItem] else { return }
        print("inputItems.count=\(items.count)")
        var i = 0
        for item in items {
            i += 1
            print("\(i): \(item)")
            print("\(i): attributed content text: \(item.attributedContentText?.string ?? "(nil)")")

            if let attachments = item.attachments {
                for attachment in attachments {
                    print("\(i): provides types: \(attachment.registeredTypeIdentifiers)")
                    for (desc, type) in [("URL", kUTTypeURL as String), ("text", kUTTypeText as String)] {
                        if attachment.hasItemConformingToTypeIdentifier(type) {
                            attachment.loadItem(forTypeIdentifier: type, options: nil) { [i = i] (value, error) in
                                guard error == nil else {
                                    print("\(i): Error loading \(desc): \(error!)")
                                    return
                                }
                                guard let value = value else {
                                    print("\(i): No error, but \(desc) was nil. :-(")
                                    return
                                }
                                print("\(i): Attached \(desc) is: \(value), of type: \(Swift.type(of: value))")
                            }
                        }
                    }
                }
            }
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        /*
         The system calls isContentValid when the user changes the text in the standard compose view, so you can display the current character count and enable the Post button when appropriate.

         If your Share extension needs to validate content in custom ways, do the validation in an override of the validateContent method. Depending on the result, you can return the correct value in your isContentValid method.
         */
        return true
    }

    override func didSelectPost() {
        /*
         Implement this method to:

         - Set up a background-mode URL session (using the NSURLSession class) that includes the content to post
         - Initiate the upload
         - Call the completeRequestReturningItems:completionHandler: method, which signals the host app that its original request is complete
         - Prepare to be terminated by the system
         */
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.

    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
