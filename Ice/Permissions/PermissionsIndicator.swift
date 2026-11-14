//
//  PermissionsIndicator.swift
//  Ice
//

import AppKit

/// Menu bar indicator shown instead of the Permissions window when permissions
/// are still missing after the first launch (audit A4). Clicking it opens the
/// window; nothing opens by itself.
@MainActor
final class PermissionsIndicator {
    private var statusItem: NSStatusItem?
    private let onClick: () -> Void

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
    }

    func show() {
        guard statusItem == nil else {
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let label = String(localized: "Permissions")
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: label)
            button.toolTip = label
            button.setAccessibilityLabel(label)
            button.target = self
            button.action = #selector(clicked)
        }
        statusItem = item
    }

    func hide() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    @objc private func clicked() {
        onClick()
    }
}
