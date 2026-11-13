//
//  ContrastPolicy.swift
//  Ice
//

import Foundation

/// sRGB color with components in 0...1, no AppKit so it compiles in the test target.
struct RGBColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// WCAG 2.2 contrast math and the fixed highlight color of the Permissions window.
enum ContrastPolicy {
    /// WCAG 2.2 AA: normal text 4.5:1, large text and graphics 3:1.
    static let minimumTextRatio = 4.5

    static func relativeLuminance(_ color: RGBColor) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    static func ratio(_ a: RGBColor, _ b: RGBColor) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Blue used for the privacy sentence in the Permissions window: dark blue on
    /// the light theme, light blue on the dark theme.
    static func permissionsHighlight(isDark: Bool) -> RGBColor {
        isDark ? RGBColor(hex: 0x80BFFF) : RGBColor(hex: 0x0B5CAD)
    }
}
