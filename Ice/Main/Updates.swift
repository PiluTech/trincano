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
        userDriverDelegate: self
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

// MARK: UpdatesManager: SPUStandardUserDriverDelegate

/// Gentle reminders: Trincano is an accessory app (no Dock icon), so Sparkle
/// would otherwise show a scheduled update window behind other apps. When an
/// update is found on its own, bring the app forward so the release notes
/// pop up where the person can see them.
extension UpdatesManager: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate, !state.userInitiated, let appState else {
            return
        }
        appState.activate(withPolicy: .regular)
    }

    func standardUserDriverWillFinishUpdateSession() {
        // Back to an accessory app once the update window is gone, unless a
        // window of ours (Settings) is still open.
        let hasOpenWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        guard !hasOpenWindow, let appState else {
            return
        }
        appState.deactivate(withPolicy: .accessory)
    }
}

// MARK: UpdatesManager: NSMenuItemValidation
extension UpdatesManager: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) {
            return canCheckForUpdates
        }
        return true
    }
}
