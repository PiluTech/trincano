//
//  Updates.swift
//  Ice
//

import Sparkle
import SwiftUI

/// Manager for app updates.
///
/// Trincano only touches the network for updates after the person agrees:
/// `SUEnableAutomaticChecks` is deliberately absent from Info.plist, so
/// Sparkle asks on the second launch and stays off until the answer is yes.
/// Updates are signed with EdDSA (`SUPublicEDKey`); the feed is HTTPS only.
@MainActor
final class UpdatesManager: NSObject, ObservableObject {
    /// A Boolean value that indicates whether the user can check for updates.
    @Published private(set) var canCheckForUpdates = false

    /// The date of the last update check.
    @Published private(set) var lastUpdateCheckDate: Date?

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// The underlying updater controller. Not started in Debug builds or in
    /// capture mode, so those never reach the network.
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: Self.isUpdaterEnabled,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private static var isUpdaterEnabled: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    /// The underlying updater.
    private var updater: SPUUpdater {
        updaterController.updater
    }

    /// A Boolean value that indicates whether to automatically check for updates.
    var automaticallyChecksForUpdates: Bool {
        get {
            updater.automaticallyChecksForUpdates
        }
        set {
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    /// Performs the initial setup of the manager.
    func performSetup(with appState: AppState) {
        self.appState = appState
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    /// Checks for app updates, showing Sparkle's standard window.
    @objc func checkForUpdates() {
        guard Self.isUpdaterEnabled, let appState else {
            return
        }
        // Activate the app so the update window comes to the front.
        appState.activate(withPolicy: .regular)
        updater.checkForUpdates()
    }
}
