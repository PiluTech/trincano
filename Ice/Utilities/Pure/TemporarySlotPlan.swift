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
        // An item already in the slot is on screen: keep it and open it in
        // place (sending it back first would press it off screen).
        let isInSlot = shown.contains(clicked)
        // Most recently shown first, so each item returns to a position that
        // is still valid.
        var steps = shown.reversed().filter { $0 != clicked }.map { Step.returnToOrigin($0) }
        steps.append(needsSlot && !isInSlot ? .showInSlot(clicked) : .openInPlace(clicked))
        return steps
    }
}

/// What `temporarilyShow` does when its task is cancelled (the queue cancels an
/// operation that ran past its deadline).
///
/// Cancellation only decides whether to *start* work (a move) or to *click*.
/// A move that finished is always registered: the item is out of its place and
/// only the registered context lets the rehide timer send it back.
enum TemporaryShowCancellation {
    /// Whether to start moving the item into the slot.
    static func startsMove(cancelled: Bool) -> Bool {
        !cancelled
    }

    /// Whether to register the context after a move that succeeded. Always.
    static func registersContext(afterSuccessfulMove cancelled: Bool) -> Bool {
        true
    }

    /// What to do once the move into the slot is over. The move itself runs
    /// shielded from cancellation (it must not stop half way and leave the
    /// item displaced), so a cancellation that arrived during it is seen only
    /// here.
    enum AfterMove: Equatable {
        /// The move failed: nothing was registered.
        case giveUp
        /// The move finished: register the context, but don't click.
        case registerOnly
        /// The move finished: register the context and go on to click.
        case registerAndClick
    }

    static func afterMove(succeeded: Bool, cancelled: Bool) -> AfterMove {
        guard succeeded else {
            return .giveUp
        }
        return cancelled ? .registerOnly : .registerAndClick
    }

    /// Whether to click the item once it is in the slot.
    static func clicks(cancelled: Bool, contextStillRegistered: Bool) -> Bool {
        !cancelled && contextStillRegistered
    }
}
