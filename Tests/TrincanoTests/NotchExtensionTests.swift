//
//  NotchExtensionTests.swift
//  TrincanoTests
//

import CoreGraphics
import Testing

struct NotchExtensionPresentationTests {
    private let notch = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        safeAreaTop: 32,
        auxiliaryTopLeftArea: CGRect(x: 0, y: 924, width: 640, height: 32),
        auxiliaryTopRightArea: CGRect(x: 830, y: 924, width: 640, height: 32)
    )

    @Test func notchScreenShowingTheHiddenSectionUsesTheExtension() {
        #expect(NotchExtensionPresentation.mode(notch: notch, isHiddenSection: true) == .notchExtension)
    }

    @Test func screenWithoutNotchKeepsTheStandardBar() {
        #expect(NotchExtensionPresentation.mode(notch: nil, isHiddenSection: true) == .standard)
    }

    @Test func otherSectionsKeepTheStandardBarEvenWithNotch() {
        #expect(NotchExtensionPresentation.mode(notch: notch, isHiddenSection: false) == .standard)
    }

    @Test func blackBackgroundOnlyWhenTheMenuBarIsDark() {
        #expect(NotchExtensionPresentation.usesBlackBackground(menuBarBrightness: 0.1))
        #expect(NotchExtensionPresentation.usesBlackBackground(menuBarBrightness: nil))
        #expect(!NotchExtensionPresentation.usesBlackBackground(menuBarBrightness: 0.9))
    }
}

struct NotchExtensionGroupsTests {
    @Test func groupsAreBehindTheNotchThenHiddenAndEmptyOnesVanish() {
        let groups = NotchExtensionGroups.make(behindNotch: [1, 2], hidden: [3])
        #expect(groups.map(\.kind) == [.behindNotch, .hidden])
        #expect(groups.map(\.items) == [[1, 2], [3]])
    }

    @Test func emptyGroupsAreDropped() {
        #expect(NotchExtensionGroups.make(behindNotch: [Int](), hidden: [3]).map(\.kind) == [.hidden])
        #expect(NotchExtensionGroups.make(behindNotch: [1], hidden: [Int]()).map(\.kind) == [.behindNotch])
    }

    @Test func noItemsMeansNoGroups() {
        #expect(NotchExtensionGroups.make(behindNotch: [Int](), hidden: [Int]()).isEmpty)
    }

    @Test func anItemBehindTheNotchIsNotRepeatedInTheHiddenGroup() {
        let groups = NotchExtensionGroups.make(behindNotch: [1, 2], hidden: [2, 3])
        #expect(groups.map(\.items) == [[1, 2], [3]])
    }
}

struct NotchExtensionFlowTests {
    @Test func rowsWrapWhenTheWidthIsExceeded() {
        let rows = FlowRows.rows(widths: [100, 100, 100, 100], maxWidth: 250, spacing: 2)
        #expect(rows == [[0, 1], [2, 3]])
    }

    @Test func spacingCountsTowardTheRowWidth() {
        // 100 + 2 + 100 = 202 fits in 202, a third would not.
        #expect(FlowRows.rows(widths: [100, 100, 100], maxWidth: 202, spacing: 2) == [[0, 1], [2]])
    }

    @Test func anItemWiderThanTheRowStaysAloneInItsRow() {
        #expect(FlowRows.rows(widths: [50, 900, 50], maxWidth: 200, spacing: 2) == [[0], [1], [2]])
    }

    @Test func noItemsMakeNoRows() {
        #expect(FlowRows.rows(widths: [], maxWidth: 200, spacing: 2).isEmpty)
    }
}

struct NotchExtensionFrameTests {
    private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    private let notchFrame = CGRect(x: 640, y: 924, width: 190, height: 32)

    @Test func isCenteredUnderTheNotchAndTouchesTheMenuBar() {
        let frame = NotchExtensionFrame.frame(size: CGSize(width: 300, height: 100), notch: notchFrame, screen: screen)
        #expect(frame.midX == notchFrame.midX)
        // Top edge on the bottom edge of the menu bar (the notch's bottom).
        #expect(frame.maxY == notchFrame.minY)
    }

    @Test func neverOverlapsTheMenuBarStrip() {
        let frame = NotchExtensionFrame.frame(size: CGSize(width: 300, height: 100), notch: notchFrame, screen: screen)
        #expect(frame.maxY <= notchFrame.minY)
    }

    @Test func staysInsideTheScreenWhenTheNotchIsOffCenter() {
        let off = CGRect(x: 100, y: 924, width: 190, height: 32)
        let frame = NotchExtensionFrame.frame(size: CGSize(width: 520, height: 100), notch: off, screen: screen)
        #expect(frame.minX >= screen.minX)
        #expect(frame.maxX <= screen.maxX)
    }

    @Test func sizeIsCappedAtTheMaximum() {
        let size = NotchExtensionFrame.clamped(CGSize(width: 2000, height: 2000))
        #expect(size.width == NotchExtensionFrame.maxWidth)
        #expect(size.height == NotchExtensionFrame.maxHeight)
    }

    @Test func sizeKeepsTheMinimumWidth() {
        #expect(NotchExtensionFrame.clamped(CGSize(width: 10, height: 10)).width == NotchExtensionFrame.minWidth)
    }
}
