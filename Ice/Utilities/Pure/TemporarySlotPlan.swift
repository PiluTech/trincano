//
//  TemporarySlotPlan.swift
//  Ice
//

/// The single "temporary place" of the Trincano Bar: the spot where a clicked
/// item that is off screen is brought into view.
///
/// Only one item sits in it at a time. Clicking another item first sends the
/// one in the slot back where it was, so nothing stacks and nothing is pushed
/// behind the notch.
enum TemporarySlotPlan<Tag: Equatable> {
    enum Step: Equatable {
        /// Send the item back to the place it came from.
        case returnToOrigin(Tag)
        /// Bring the item into the slot and click it.
        case showInSlot(Tag)
        /// The item is already on screen: open its menu where it is.
        case openInPlace(Tag)
    }

    /// - Parameters:
    ///   - shown: The items currently in the slot, oldest first.
    ///   - clicked: The item the user clicked.
    ///   - needsSlot: Whether the clicked item is off screen.
    static func steps(shown: [Tag], clicked: Tag, needsSlot: Bool) -> [Step] {
        // Most recently shown first, so each item returns to a position that
        // is still valid. The clicked item returns too (and re-enters), which
        // keeps its return destination computed from the real origin.
        var steps = shown.reversed().map { Step.returnToOrigin($0) }
        steps.append(needsSlot ? .showInSlot(clicked) : .openInPlace(clicked))
        return steps
    }
}
