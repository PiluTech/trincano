//
//  TargetSize.swift
//  Ice
//

import CoreGraphics

/// Click-target sizes (audit A2). WCAG 2.2 (2.5.8) asks for 24 pt everywhere; the
/// PiluTech standard asks for 44 pt on primary controls and on anything new.
/// The app also runs with a pointer in a dense menu bar, so 24 pt is the hard
/// floor and 44 pt applies to main controls.
enum TargetSize {
    static let minimum: CGFloat = 24
    static let primary: CGFloat = 44

    /// A row of `SectionedList`.
    static let sectionedListItem = CGSize(width: 24, height: 24)
    /// `HotkeyRecorder` (two segments).
    static let hotkeyRecorder = CGSize(width: 132, height: 24)
    /// `IceGradientPicker`.
    static let gradientPicker = CGSize(width: 200, height: 24)
    /// The notch extension's buttons.
    static let notchExtensionButton = CGSize(width: 30, height: 28)
    /// Label of the Search panel's bottom bar buttons, before `bottomBarButtonPadding`.
    static let bottomBarButtonLabel = CGSize(width: 22, height: 22)
    static let bottomBarButtonPadding: CGFloat = 3
    /// The permission row control in Advanced settings.
    static let advancedPermissionRowHeight: CGFloat = 24

    /// Effective size of a bottom bar button (label plus padding on both sides).
    static var bottomBarButton: CGSize {
        CGSize(
            width: bottomBarButtonLabel.width + 2 * bottomBarButtonPadding,
            height: bottomBarButtonLabel.height + 2 * bottomBarButtonPadding
        )
    }
}
