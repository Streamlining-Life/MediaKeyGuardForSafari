//
//  ViewController.swift
//  MediaKeyGuardForSafari
//
//  Created by Gareth Blain on 11/08/2026.
//

import Cocoa
import SafariServices
import WebKit

let extensionBundleIdentifier = "Life.Streamlining.MediaKeyGuardForSafari.Extension"

class ViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView.navigationDelegate = self

        self.webView.configuration.userContentController.add(self, name: "controller")

        self.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
            guard let state = state, error == nil else {
                // Insert code to inform the user that something went wrong.
                return
            }

            DispatchQueue.main.async {
                webView.evaluateJavaScript("show(\(state.isEnabled), true)")
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Main.html is loaded from file:// — the only other navigation it can
        // start is the help link, which belongs in the user's browser. Handing
        // it to NSWorkspace instead of loading it here keeps the app off the
        // network entirely, so it needs no outgoing-connection entitlement.
        guard let url = navigationAction.request.url, !url.isFileURL else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // as? not as! — a force cast traps the whole app on any body that isn't
        // a String. Only Script.js posts here and it posts that one string, but
        // a crash is a steep price for a message we can simply ignore.
        guard message.body as? String == "open-preferences" else { return }

        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

}
