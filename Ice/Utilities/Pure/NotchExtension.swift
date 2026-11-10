//
//  NotchExtension.swift
//  Ice
//

import CoreGraphics

/// How the Trincano Bar is presented on a screen: the standard bar, or the
/// "extension of the notch" that grows out of the notch.
enum NotchExtensionPresentation {
    enum Mode: Equatable {
        case standard
        case notchExtension
    }

    /// The extension exists only on a screen with a notch and only for the
    /// hidden section. Everything else keeps the standard bar, which is also
    /// the safe path when the notch geometry is missing.
    static func mode(notch: NotchGeometry?, isHiddenSection: Bool) -> Mode {
        notch != nil && isHiddenSection ? .notchExtension : .standard
    }

    /// The extension is black to merge with the notch. Items are captured from
    /// the menu bar in its own colors, so on a light menu bar (dark glyphs)
    /// a black background would hide them: the caller then keeps the regular
    /// bar background.
    static func usesBlackBackground(menuBarBrightness: Double?) -> Bool {
        (menuBarBrightness ?? 0) <= 0.67
    }
}

/// The groups listed in the extension: items the system pushed behind the
/// notch first, then the other hidden items.
enum NotchExtensionGroups {
    enum Kind: Equatable {
        case behindNotch
        case hidden
    }

    struct Group<T> {
        let kind: Kind
        let items: [T]
    }

    static func make<T, ID: Hashable>(behindNotch: [T], hidden: [T], id: (T) -> ID) -> [Group<T>] {
        let stuckIDs = Set(behindNotch.map(id))
        let rest = hidden.filter { !stuckIDs.contains(id($0)) }
        return [Group(kind: .behindNotch, items: behindNotch), Group(kind: .hidden, items: rest)]
            .filter { !$0.items.isEmpty }
    }

    static func make<T: Hashable>(behindNotch: [T], hidden: [T]) -> [Group<T>] {
        make(behindNotch: behindNotch, hidden: hidden) { $0 }
    }
}

/// Splits items into wrapped rows.
enum FlowRows {
    /// Returns the item indices of each row. An item wider than the row stays
    /// alone in its own row.
    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows = [[Int]]()
        var current = [Int]()
        var currentWidth: CGFloat = 0
        for (index, width) in widths.enumerated() {
            let needed = current.isEmpty ? width : currentWidth + spacing + width
            if !current.isEmpty, needed > maxWidth {
                rows.append(current)
                current = [index]
                currentWidth = width
            } else {
                current.append(index)
                currentWidth = needed
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// Where the extension goes and how big it can be.
enum NotchExtensionFrame {
    static let minWidth: CGFloat = 180
    static let maxWidth: CGFloat = 520
    /// Three rows of items plus the group labels, then it scrolls.
    static let maxHeight: CGFloat = 236
    /// Transparent margin around the content (sides and bottom) for the shadow.
    static let outerInset: CGFloat = 8
    /// Limits of the content so that content + outer inset is never bigger
    /// than the maximum panel.
    static let contentMaxWidth: CGFloat = maxWidth - outerInset * 2
    static let contentMaxHeight: CGFloat = maxHeight - outerInset

    static func clamped(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minWidth), maxWidth),
            height: min(size.height, maxHeight)
        )
    }

    /// The panel frame in AppKit coordinates (y up): centered under the notch,
    /// its top edge on the bottom edge of the menu bar (never over the menu
    /// bar, so the notch click handling is unaffected), and inside the screen.
    /// `size` is the real panel size (content plus outer inset), already
    /// limited by the view to `maxWidth` x `maxHeight`.
    static func frame(size: CGSize, notch: CGRect, screen: CGRect) -> CGRect {
        let upper = max(screen.minX, screen.maxX - size.width)
        let x = min(max(notch.midX - size.width / 2, screen.minX), upper)
        return CGRect(x: x, y: notch.minY - size.height, width: size.width, height: size.height)
    }
}
