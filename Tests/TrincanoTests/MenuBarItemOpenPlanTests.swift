//
//  MenuBarItemOpenPlanTests.swift
//  TrincanoTests
//

import CoreGraphics
import Testing

struct MenuBarItemOpenPlanTests {
    @Test func onScreenLeftClickUsesAccessibilityPress() {
        #expect(MenuBarItemOpenPlan.strategy(isOnScreen: true, isLeftButton: true) == .accessibilityPress)
    }

    @Test func offScreenItemMovesAndClicks() {
        #expect(MenuBarItemOpenPlan.strategy(isOnScreen: false, isLeftButton: true) == .moveAndClick)
    }

    @Test func rightClickKeepsTheSyntheticClick() {
        #expect(MenuBarItemOpenPlan.strategy(isOnScreen: true, isLeftButton: false) == .syntheticClick)
        #expect(MenuBarItemOpenPlan.strategy(isOnScreen: false, isLeftButton: false) == .moveAndClick)
    }

    @Test func matchesTheCandidateWithTheSameFrame() {
        let item = CGRect(x: 1123, y: 4, width: 64, height: 24)
        let candidates: [CGRect?] = [
            CGRect(x: 1041, y: 4, width: 36, height: 24),
            CGRect(x: 1124, y: 4, width: 64, height: 24),
        ]
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: candidates) == 1)
    }

    @Test func picksTheClosestWhenSeveralAreNear() {
        let item = CGRect(x: 100, y: 4, width: 30, height: 24)
        let candidates: [CGRect?] = [
            CGRect(x: 104, y: 4, width: 30, height: 24),
            CGRect(x: 101, y: 4, width: 30, height: 24),
        ]
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: candidates) == 1)
    }

    @Test func rejectsFramesFarFromTheItem() {
        let item = CGRect(x: 1123, y: 4, width: 64, height: 24)
        let candidates: [CGRect?] = [CGRect(x: -4086, y: 4, width: 64, height: 24), nil]
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: candidates) == nil)
    }

    @Test func rejectsDifferentSizes() {
        let item = CGRect(x: 100, y: 4, width: 30, height: 24)
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: [CGRect(x: 100, y: 4, width: 90, height: 24)]) == nil)
    }

    // MARK: Tolerance boundary and stacked screens

    private let item = CGRect(x: 100, y: 4, width: 30, height: 24)

    private func match(_ candidate: CGRect) -> Int? {
        MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: [candidate])
    }

    @Test func toleranceBoundaryOnEachAxis() {
        #expect(match(CGRect(x: 108, y: 4, width: 30, height: 24)) == 0)
        #expect(match(CGRect(x: 109, y: 4, width: 30, height: 24)) == nil)
        #expect(match(CGRect(x: 100, y: 12, width: 30, height: 24)) == 0)
        #expect(match(CGRect(x: 100, y: 13, width: 30, height: 24)) == nil)
        #expect(match(CGRect(x: 100, y: 4, width: 38, height: 24)) == 0)
        #expect(match(CGRect(x: 100, y: 4, width: 39, height: 24)) == nil)
        #expect(match(CGRect(x: 100, y: 4, width: 30, height: 32)) == 0)
        #expect(match(CGRect(x: 100, y: 4, width: 30, height: 33)) == nil)
    }

    @Test func negativeOffsetsUseTheSameBoundary() {
        #expect(match(CGRect(x: 92, y: -4, width: 22, height: 16)) == 0)
        #expect(match(CGRect(x: 91, y: 4, width: 30, height: 24)) == nil)
    }

    @Test func rejectsTheSameXAndSizeOnAnotherRow() {
        #expect(match(CGRect(x: 100, y: 1084, width: 30, height: 24)) == nil)
        #expect(match(CGRect(x: 100, y: 40, width: 30, height: 24)) == nil)
    }

    @Test func stackedScreensPickTheRowOfTheItem() {
        let lower = CGRect(x: 100, y: 1084, width: 30, height: 24)
        let candidates: [CGRect?] = [CGRect(x: 100, y: 4, width: 30, height: 24), lower]
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: lower, candidates: candidates) == 1)
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: candidates) == 0)
        // Only the other screen's frame is available: no match, so no wrong press.
        #expect(MenuBarItemOpenPlan.matchIndex(itemBounds: item, candidates: [lower]) == nil)
    }

    // MARK: Press outcome

    @Test func onlyAnUnavailablePressFallsBackToAClick() {
        #expect(MenuBarItemOpenPlan.PressOutcome.pressed.fallsBackToClick == false)
        #expect(MenuBarItemOpenPlan.PressOutcome.unavailable.fallsBackToClick == true)
        // After a timeout the press may have gone through: a click would open it twice.
        #expect(MenuBarItemOpenPlan.PressOutcome.uncertain.fallsBackToClick == false)
    }

    @Test func aPressCancelledAfterItRanDoesNotClick() {
        // Not cancelled: only an unavailable press falls back to the click.
        #expect(MenuBarItemOpenPlan.shouldClickAfterPress(.unavailable, isCancelled: false))
        #expect(!MenuBarItemOpenPlan.shouldClickAfterPress(.pressed, isCancelled: false))
        #expect(!MenuBarItemOpenPlan.shouldClickAfterPress(.uncertain, isCancelled: false))
        // Cancelled (past the deadline during the press): no click afterwards.
        #expect(!MenuBarItemOpenPlan.shouldClickAfterPress(.unavailable, isCancelled: true))
        #expect(!MenuBarItemOpenPlan.shouldClickAfterPress(.pressed, isCancelled: true))
        #expect(!MenuBarItemOpenPlan.shouldClickAfterPress(.uncertain, isCancelled: true))
    }

    @Test func onlyAnEnabledMenuBarItemIsPressable() {
        #expect(MenuBarItemOpenPlan.isPressable(isMenuBarItem: true, isEnabled: true))
        #expect(!MenuBarItemOpenPlan.isPressable(isMenuBarItem: false, isEnabled: true))
        #expect(!MenuBarItemOpenPlan.isPressable(isMenuBarItem: true, isEnabled: false))
    }
}
