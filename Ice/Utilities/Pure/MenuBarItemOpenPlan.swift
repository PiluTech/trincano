//
//  MenuBarItemOpenPlan.swift
//  Ice
//

import CoreGraphics

/// How the Trincano Bar opens the menu of an app's menu bar item that the user
/// clicked in the panel.
enum MenuBarItemOpenPlan {
    enum Strategy: Equatable {
        /// Press the item through Accessibility, without moving it: the app
        /// draws its own menu anchored to the item where it already is.
        case accessibilityPress
        /// Click the item where it is (a right click has no Accessibility
        /// equivalent for status items).
        case syntheticClick
        /// The item is off screen, so its menu would be drawn off screen too:
        /// bring it into view, click, and send it back.
        case moveAndClick
    }

    /// The result of an Accessibility press.
    enum PressOutcome: Equatable {
        case pressed
        /// Nothing was pressed (no matching element, or the action is refused).
        case unavailable
        /// The call timed out: the press may have gone through, so clicking
        /// again could open the menu twice.
        case uncertain

        var fallsBackToClick: Bool { self == .unavailable }
    }

    /// Only an enabled `AXMenuBarItem` is pressed.
    static func isPressable(isMenuBarItem: Bool, isEnabled: Bool) -> Bool {
        isMenuBarItem && isEnabled
    }

    static func strategy(isOnScreen: Bool, isLeftButton: Bool) -> Strategy {
        guard isOnScreen else {
            return .moveAndClick
        }
        return isLeftButton ? .accessibilityPress : .syntheticClick
    }

    /// Returns the index of the Accessibility frame that belongs to the item,
    /// or `nil` when none is close enough (the caller falls back to a click).
    ///
    /// Both frames are in the same top-left screen coordinates. The nearest
    /// origin wins, within ``tolerance`` on each axis and on the size.
    static func matchIndex(itemBounds: CGRect, candidates: [CGRect?], tolerance: CGFloat = 8) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, candidate) in candidates.enumerated() {
            guard let candidate else {
                continue
            }
            let dx = abs(candidate.minX - itemBounds.minX)
            let dy = abs(candidate.minY - itemBounds.minY)
            guard
                dx <= tolerance,
                dy <= tolerance,
                abs(candidate.width - itemBounds.width) <= tolerance,
                abs(candidate.height - itemBounds.height) <= tolerance
            else {
                continue
            }
            let distance = dx + dy
            if best.map({ distance < $0.distance }) ?? true {
                best = (index, distance)
            }
        }
        return best?.index
    }
}
