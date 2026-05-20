//
//  CPYUpdatesPreferenceViewController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/03/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Combine
import Sparkle

class CPYUpdatesPreferenceViewController: NSViewController {

    // MARK: - Properties
    @IBOutlet private weak var lastUpdateCheckDateTextField: NSTextField!
    @IBOutlet private weak var versionTextField: NSTextField!

    private var updaterController: SPUStandardUpdaterController? {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return nil }
        return appDelegate.updaterController
    }
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Initialize
    override func loadView() {
        super.loadView()
        versionTextField.stringValue = "v\(Bundle.main.appVersion ?? "")"

        guard let updaterController = updaterController else {
            configureUpdatesDisabled()
            return
        }

        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .compactMap { $0 }
            .assign(to: \.objectValue, on: lastUpdateCheckDateTextField)
            .store(in: &cancellables)
    }

    @IBAction private func checkForUpdates(_ sender: Any) {
        guard let updaterController = updaterController else { return }
        updaterController.checkForUpdates(sender)
    }

    private func configureUpdatesDisabled() {
        lastUpdateCheckDateTextField.stringValue = "Updates disabled for local build"
        checkForUpdatesButton(in: view)?.isEnabled = false
    }

    private func checkForUpdatesButton(in view: NSView) -> NSButton? {
        for subview in view.subviews {
            if let button = subview as? NSButton, button.action == #selector(checkForUpdates(_:)) {
                return button
            }
            if let button = checkForUpdatesButton(in: subview) {
                return button
            }
        }
        return nil
    }
}
