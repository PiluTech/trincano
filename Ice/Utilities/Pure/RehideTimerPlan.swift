//
//  RehideTimerPlan.swift
//  Ice
//

/// Decides whether the rehide timer must be armed again.
enum RehideTimerPlan {
    /// A partial return (for example only the previous item when another is
    /// clicked) cancels the timer; the items left in the slot still need one,
    /// or they would stay on the bar forever.
    static func needsRearm(remainingItems: Int, timerIsScheduled: Bool) -> Bool {
        remainingItems > 0 && !timerIsScheduled
    }
}
