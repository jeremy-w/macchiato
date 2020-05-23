//
//  ShareViewController.swift
//  Share
//
//  Created by Jeremy W. Sherman on 2020-05-23.
//  Copyright © 2020 Jeremy W. Sherman. All rights reserved.
//

import UIKit
import Social

/**
 System extension point for sharing.

 See: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
 */
class ShareViewController: SLComposeServiceViewController {

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
