//
//  RehideTimerPlanTests.swift
//  TrincanoTests
//

import Testing

struct RehideTimerPlanTests {
    @Test func partialReturnLeavesAnItemWithoutTimerSoItRearms() {
        // shown = [A, B]; clicking B returns only A and cancels the timer.
        #expect(RehideTimerPlan.needsRearm(remainingItems: 1, timerIsScheduled: false))
    }

    @Test func doesNotRearmWhenNothingIsLeft() {
        #expect(!RehideTimerPlan.needsRearm(remainingItems: 0, timerIsScheduled: false))
    }

    @Test func doesNotDoubleArmWhenATimerIsAlreadyRunning() {
        #expect(!RehideTimerPlan.needsRearm(remainingItems: 2, timerIsScheduled: true))
    }
}
