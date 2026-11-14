//
//  TargetSizeTests.swift
//  TrincanoTests
//

import CoreGraphics
import Testing

struct TargetSizeTests {
    @Test func thresholdsFollowWCAG22AndThePiluTechStandard() {
        #expect(TargetSize.minimum == 24)
        #expect(TargetSize.primary == 44)
    }

    @Test func everyClickTargetMeetsTheHardMinimum() {
        let targets: [(String, CGSize)] = [
            ("sectionedListItem", TargetSize.sectionedListItem),
            ("hotkeyRecorder", TargetSize.hotkeyRecorder),
            ("gradientPicker", TargetSize.gradientPicker),
            ("notchExtensionButton", TargetSize.notchExtensionButton),
            ("bottomBarButton", TargetSize.bottomBarButton),
            ("advancedPermissionRow", CGSize(width: TargetSize.minimum, height: TargetSize.advancedPermissionRowHeight)),
        ]
        for (name, size) in targets {
            #expect(size.width >= TargetSize.minimum && size.height >= TargetSize.minimum, "\(name): \(size)")
        }
    }
}
