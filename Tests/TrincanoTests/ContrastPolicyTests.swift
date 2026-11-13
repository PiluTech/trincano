//
//  ContrastPolicyTests.swift
//  TrincanoTests
//

import Testing

struct ContrastPolicyTests {
    @Test func ratioMatchesWCAGReferenceValues() {
        let white = RGBColor(hex: 0xFFFFFF)
        let black = RGBColor(hex: 0x000000)
        #expect(abs(ContrastPolicy.ratio(white, black) - 21) < 0.001)
        #expect(abs(ContrastPolicy.ratio(white, white) - 1) < 0.001)
    }

    @Test func permissionsHighlightPassesAAOnLightBackgrounds() {
        let color = ContrastPolicy.permissionsHighlight(isDark: false)
        for background: UInt32 in [0xFFFFFF, 0xECECEC] {
            let ratio = ContrastPolicy.ratio(color, RGBColor(hex: background))
            #expect(ratio >= ContrastPolicy.minimumTextRatio, "light \(String(background, radix: 16)): \(ratio)")
        }
    }

    @Test func permissionsHighlightPassesAAOnDarkBackgrounds() {
        let color = ContrastPolicy.permissionsHighlight(isDark: true)
        for background: UInt32 in [0x1E1E1E, 0x323232] {
            let ratio = ContrastPolicy.ratio(color, RGBColor(hex: background))
            #expect(ratio >= ContrastPolicy.minimumTextRatio, "dark \(String(background, radix: 16)): \(ratio)")
        }
    }
}
