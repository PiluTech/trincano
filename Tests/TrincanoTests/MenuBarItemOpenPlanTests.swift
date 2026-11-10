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
}
