//
//  MenuBarItemAccessibilityPress.swift
//  Ice
//

import AXSwift
import Cocoa
import os

extension MenuBarItemManager {
    /// Presses the item through Accessibility, so the owning app draws its own
    /// menu anchored to the item where it already is (nothing is moved and no
    /// synthetic mouse event is posted).
    ///
    /// Returns `false` when the item can't be found or the press is refused;
    /// the caller then falls back to a click.
    func pressThroughAccessibility(item: MenuBarItem) async -> Bool {
        let pid = item.sourcePID ?? item.ownerPID
        let bounds = Bridging.getWindowBounds(for: item.windowID) ?? item.bounds
        let pressed = await Task.detached(priority: .userInitiated) {
            Self.performAccessibilityPress(pid: pid, bounds: bounds)
        }.value
        Logger.default.notice(
            "Accessibility press for \(item.logString, privacy: .public): \(pressed ? "ok" : "unavailable", privacy: .public)"
        )
        return pressed
    }

    /// Accessibility calls can block on an unresponsive app, so this runs off
    /// the main actor.
    private nonisolated static func performAccessibilityPress(pid: pid_t, bounds: CGRect) -> Bool {
        guard
            AXHelpers.isProcessTrusted(),
            let runningApp = NSRunningApplication(processIdentifier: pid),
            let app = AXHelpers.application(for: runningApp),
            let extras = AXHelpers.extrasMenuBar(for: app)
        else {
            return false
        }
        let children = AXHelpers.children(for: extras)
        let frames = children.map { AXHelpers.frame(for: $0) }
        guard let index = MenuBarItemOpenPlan.matchIndex(itemBounds: bounds, candidates: frames) else {
            return false
        }
        do {
            try children[index].performAction(.press)
            return true
        } catch {
            return false
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
            if await pressThroughAccessibility(item: item) {
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
