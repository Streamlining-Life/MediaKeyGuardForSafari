//
//  SafariWebExtensionHandler.swift
//  MediaKeyGuardForSafari Extension
//
//  Created by Gareth Blain on 11/08/2026.
//

import SafariServices

// Required: the appex's Info.plist names this as NSExtensionPrincipalClass, so
// the class has to exist for the extension to load. It never runs — nothing
// calls browser.runtime.sendNativeMessage, and manifest.json doesn't request
// the nativeMessaging permission it would need to. The Xcode template's echo
// and os_log body is gone; there is no message to echo or log.
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        context.completeRequest(returningItems: [], completionHandler: nil)
    }

}
