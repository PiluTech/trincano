//
//  MenuBarItemAccessibilityPress.swift
//  Ice
//

import AXSwift
import Cocoa
import os

extension MenuBarItemManager {
    /// How long one Accessibility call may block on an unresponsive app.
    private nonisolated static let accessibilityTimeout: Float = 1

    /// Presses the item through Accessibility, so the owning app draws its own
    /// menu anchored to the item where it already is (nothing is moved and no
    /// synthetic mouse event is posted).
    ///
    /// Known limit: a press that succeeds but that the app ignores has no
    /// fallback, because Accessibility reports success either way.
    func pressThroughAccessibility(item: MenuBarItem) async -> MenuBarItemOpenPlan.PressOutcome {
        let pid = item.sourcePID ?? item.ownerPID
        let bounds = Bridging.getWindowBounds(for: item.windowID) ?? item.bounds
        let outcome = await Task.detached(priority: .userInitiated) {
            Self.performAccessibilityPress(pid: pid, bounds: bounds)
        }.value
        Logger.default.notice(
            "Accessibility press for \(item.logString, privacy: .public): \(String(describing: outcome), privacy: .public)"
        )
        return outcome
    }

    /// Accessibility calls can block on an unresponsive app, so this runs off
    /// the main actor, with a short messaging timeout.
    private nonisolated static func performAccessibilityPress(
        pid: pid_t,
        bounds: CGRect
    ) -> MenuBarItemOpenPlan.PressOutcome {
        guard
            AXHelpers.isProcessTrusted(),
            let runningApp = NSRunningApplication(processIdentifier: pid),
            let app = AXHelpers.application(for: runningApp)
        else {
            return .unavailable
        }
        AXUIElementSetMessagingTimeout(app.element, accessibilityTimeout)
        guard let extras = AXHelpers.extrasMenuBar(for: app) else {
            return .unavailable
        }
        let children = AXHelpers.children(for: extras)
        let frames = children.map { AXHelpers.frame(for: $0) }
        guard
            let index = MenuBarItemOpenPlan.matchIndex(itemBounds: bounds, candidates: frames),
            MenuBarItemOpenPlan.isPressable(
                isMenuBarItem: AXHelpers.roleName(for: children[index]) == "AXMenuBarItem",
                isEnabled: AXHelpers.isEnabled(children[index])
            )
        else {
            return .unavailable
        }
        do {
            try children[index].performAction(.press)
            return .pressed
        } catch AXError.cannotComplete {
            // Includes a messaging timeout: the press may have gone through.
            return .uncertain
        } catch {
            return .unavailable
        }
    }
}

extension MenuBarItemManager {
    /// Opens the menu of the item the user chose in the Trincano Bar.
    ///
    /// An item on screen (including one behind the notch) is pressed through
    /// Accessibility without moving it; a right click, or an item that can't be
    /// pressed, is clicked in place. An item off screen is brought into view,
    /// clicked, and returned (see ``temporarilyShow(item:clickingWith:)``).
    func open(item: MenuBarItem, with mouseButton: CGMouseButton) async {
        let strategy = MenuBarItemOpenPlan.strategy(
            isOnScreen: Bridging.isWindowOnScreen(item.windowID),
            isLeftButton: mouseButton == .left
        )
        switch strategy {
        case .moveAndClick:
            await temporarilyShow(item: item, clickingWith: mouseButton)
        case .accessibilityPress:
            if await !pressThroughAccessibility(item: item).fallsBackToClick {
                return
            }
            await clickInPlace(item: item, with: mouseButton)
        case .syntheticClick:
            await clickInPlace(item: item, with: mouseButton)
        }
    }

    private func clickInPlace(item: MenuBarItem, with mouseButton: CGMouseButton) async {
        do {
            try await click(item: item, with: mouseButton)
        } catch {
            Logger.default.error("Error clicking \(item.logString, privacy: .public): \(error, privacy: .public)")
        }
    }
}
