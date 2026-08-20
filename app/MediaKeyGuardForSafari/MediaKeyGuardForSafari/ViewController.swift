//
//  ViewController.swift
//  MediaKeyGuardForSafari
//
//  Created by Gareth Blain on 11/08/2026.
//

import Cocoa
import SafariServices

let extensionBundleIdentifier = "Life.Streamlining.MediaKeyGuardForSafari.Extension"

class ViewController: NSViewController {

    private let stateLabel = NSTextField(wrappingLabelWithString: "You can turn on Media Key Guard for Safari’s extension in the Extensions section of Safari Settings.")

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshExtensionState()
    }

    private func buildInterface() {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Media Key Guard for Safari")
        title.font = .boldSystemFont(ofSize: 18)

        let tagline = NSTextField(wrappingLabelWithString: """
            Stops short notification sounds (Teams, Slack, web mail…) from \
            stealing your Mac's play/pause key away from Spotify or Music. \
            Real media — videos, podcasts, live streams — keeps working normally.
            """)
        tagline.alignment = .center

        stateLabel.alignment = .center

        let openSettingsButton = NSButton(title: "Quit and Open Safari Settings…",
                                          target: self,
                                          action: #selector(openSafariSettings))

        let stack = NSStackView(views: [icon, title, tagline, stateLabel, openSettingsButton, makeFootnote()])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalToConstant: 96),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
        ])
    }

    private func makeFootnote() -> NSTextField {
        let text = """
            Once enabled, allow it on the sites you use (or all websites), \
            then use the toolbar icon to exclude any site you want left alone.
            Help & source: github.com/Streamlining-Life/MediaKeyGuardForSafari
            """
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let footnote = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ])
        footnote.addAttribute(.link,
                              value: URL(string: "https://github.com/Streamlining-Life/MediaKeyGuardForSafari#readme")!,
                              range: (text as NSString).range(of: "github.com/Streamlining-Life/MediaKeyGuardForSafari"))

        let label = NSTextField(wrappingLabelWithString: "")
        label.attributedStringValue = footnote
        // Both required for the .link attribute to be clickable in a label.
        label.isSelectable = true
        label.allowsEditingTextAttributes = true
        return label
    }

    private func refreshExtensionState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { state, error in
            guard let state, error == nil else { return }

            DispatchQueue.main.async {
                self.stateLabel.stringValue = state.isEnabled
                    ? "Media Key Guard for Safari’s extension is currently on. You can turn it off in the Extensions section of Safari Settings."
                    : "Media Key Guard for Safari’s extension is currently off. You can turn it on in the Extensions section of Safari Settings."
            }
        }
    }

    @objc private func openSafariSettings(_ sender: Any?) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

}
