//
//  TemporarySlotPlanTests.swift
//  TrincanoTests
//

import Testing

struct TemporarySlotPlanTests {
    typealias Plan = TemporarySlotPlan<String>

    /// A tiny model of the bar: the visible items right of the notch, the
    /// hidden ones, and where each shown item came from.
    private struct BarModel {
        var visible: [String]
        var hidden: [String]
        var slot: [String] = []

        mutating func run(_ steps: [Plan.Step]) {
            for step in steps {
                switch step {
                case .returnToOrigin(let tag):
                    visible.removeAll { $0 == tag }
                    slot.removeAll { $0 == tag }
                    hidden.append(tag)
                case .showInSlot(let tag):
                    hidden.removeAll { $0 == tag }
                    visible.insert(tag, at: 0) // the slot: left of the first visible item
                    slot.append(tag)
                case .openInPlace:
                    break
                }
            }
        }
    }

    @Test func firstClickJustShowsTheItem() {
        #expect(Plan.steps(shown: [], clicked: "A", needsSlot: true) == [.showInSlot("A")])
    }

    @Test func clickingAnotherReturnsThePreviousFirst() {
        #expect(
            Plan.steps(shown: ["A"], clicked: "B", needsSlot: true)
                == [.returnToOrigin("A"), .showInSlot("B")]
        )
    }

    @Test func swapKeepsTheVisibleCountAndASingleItemInTheSlot() {
        var bar = BarModel(visible: ["Clock", "Wifi"], hidden: ["A", "B", "C"])
        bar.run(Plan.steps(shown: bar.slot, clicked: "A", needsSlot: true))
        let countWithA = bar.visible.count
        #expect(bar.visible == ["A", "Clock", "Wifi"])

        bar.run(Plan.steps(shown: bar.slot, clicked: "B", needsSlot: true))
        #expect(bar.visible == ["B", "Clock", "Wifi"])
        #expect(bar.visible.count == countWithA)
        #expect(bar.slot == ["B"])
        #expect(bar.hidden.contains("A"))
        #expect(!bar.hidden.contains("B"))

        bar.run(Plan.steps(shown: bar.slot, clicked: "C", needsSlot: true))
        #expect(bar.visible == ["C", "Clock", "Wifi"])
        #expect(Set(bar.hidden) == ["A", "B"])
    }

    @Test func clickingTheItemInTheSlotAgainDoesNotStack() {
        var bar = BarModel(visible: ["Clock"], hidden: ["A"])
        bar.run(Plan.steps(shown: bar.slot, clicked: "A", needsSlot: true))
        bar.run(Plan.steps(shown: bar.slot, clicked: "A", needsSlot: true))
        #expect(bar.visible == ["A", "Clock"])
        #expect(bar.slot == ["A"])
    }

    @Test func anItemOnScreenReturnsTheSlotAndOpensInPlace() {
        #expect(
            Plan.steps(shown: ["A"], clicked: "N", needsSlot: false)
                == [.returnToOrigin("A"), .openInPlace("N")]
        )
        #expect(Plan.steps(shown: [], clicked: "N", needsSlot: false) == [.openInPlace("N")])
    }

    @Test func staleEntriesReturnNewestFirst() {
        #expect(
            Plan.steps(shown: ["A", "B"], clicked: "C", needsSlot: true)
                == [.returnToOrigin("B"), .returnToOrigin("A"), .showInSlot("C")]
        )
    }

    // MARK: Real path: the item in the slot is on screen

    @Test func reclickingTheItemInTheSlotKeepsItAndOpensInPlace() {
        // The real caller computes needsSlot from the item being off screen:
        // an item already in the slot is on screen, so needsSlot is false.
        #expect(
            Plan.steps(shown: ["A"], clicked: "A", needsSlot: false)
                == [.openInPlace("A")]
        )
        // Even if the caller still says it needs the slot, A is not sent back.
        #expect(
            Plan.steps(shown: ["A"], clicked: "A", needsSlot: true)
                == [.openInPlace("A")]
        )
    }

    @Test func reclickingKeepsTheClickedAndReturnsTheOthers() {
        #expect(
            Plan.steps(shown: ["A", "B"], clicked: "B", needsSlot: false)
                == [.returnToOrigin("A"), .openInPlace("B")]
        )
    }
}

@MainActor
struct SerialAsyncQueueTests {
    @Test func operationsDoNotInterleave() async {
        let queue = SerialAsyncQueue()
        let log = Log()

        // `async let` doesn't promise a start order; main-actor Tasks do.
        let first = Task { @MainActor in
            await queue.run {
                log.add("A start")
                await Task.yield()
                await Task.yield()
                log.add("A end")
            }
        }
        let second = Task { @MainActor in
            await queue.run {
                log.add("B start")
                await Task.yield()
                log.add("B end")
            }
        }
        _ = await (first.value, second.value)

        #expect(log.entries == ["A start", "A end", "B start", "B end"])
    }

    @Test func aStuckOperationIsCancelledAndDoesNotBlockTheNextOne() async {
        // The deadline is a manual gate, not a sleep: no wall-clock time.
        let gate = Gate()
        var timeouts = 0
        let queue = SerialAsyncQueue(
            timeout: .seconds(5),
            onTimeout: { timeouts += 1 },
            sleep: { _ in
                for _ in 0..<Self.maxIterations where !Task.isCancelled {
                    if await gate.isOpen { return }
                    await Task.yield()
                }
            }
        )
        let log = Log()

        let stuck = Task { @MainActor in
            await queue.run {
                log.add("stuck start")
                // Bounded: a queue that never cancels fails the test, not hangs it.
                for _ in 0..<Self.maxIterations where !Task.isCancelled {
                    await Task.yield()
                }
                if Task.isCancelled { log.add("stuck cancelled") }
            }
        }
        // Submit "next" only once "stuck" is running: the order is certain.
        for _ in 0..<Self.maxIterations where !log.entries.contains("stuck start") {
            await Task.yield()
        }
        let next = Task { @MainActor in
            await queue.run {
                log.add("next")
            }
        }
        await gate.open()
        _ = await (stuck.value, next.value)

        #expect(log.entries.first == "stuck start")
        #expect(Set(log.entries) == ["stuck start", "stuck cancelled", "next"])
        #expect(timeouts == 1)
    }

    @Test func anOperationThatFinishesInTimeIsNotCancelled() async {
        var timeouts = 0
        let queue = SerialAsyncQueue(onTimeout: { timeouts += 1 }, sleep: { _ in
            // Never reaches the deadline; ends when the queue cancels the timer.
            for _ in 0..<Self.maxIterations where !Task.isCancelled {
                await Task.yield()
            }
        })
        let wasCancelled = await queue.run { Task.isCancelled }
        #expect(!wasCancelled)
        #expect(timeouts == 0)
    }

    @Test func runsInSubmissionOrderAndReturnsTheValue() async {
        let queue = SerialAsyncQueue()
        let value = await queue.run { 42 }
        #expect(value == 42)
    }

    nonisolated static let maxIterations = 200_000

    actor Gate {
        private(set) var isOpen = false
        func open() { isOpen = true }
    }

    @MainActor
    final class Log {
        var entries = [String]()
        func add(_ entry: String) { entries.append(entry) }
    }
}

struct TemporaryShowCancellationTests {
    typealias Plan = TemporarySlotPlan<String>

    @Test func aCancelledOperationDoesNotStartAMove() {
        #expect(!TemporaryShowCancellation.startsMove(cancelled: true))
        #expect(TemporaryShowCancellation.startsMove(cancelled: false))
    }

    @Test func cancelledDuringTheMoveStillRegistersAndOnlySkipsTheClick() {
        #expect(TemporaryShowCancellation.afterMove(succeeded: true, cancelled: true) == .registerOnly)
        #expect(TemporaryShowCancellation.afterMove(succeeded: true, cancelled: false) == .registerAndClick)
        #expect(TemporaryShowCancellation.afterMove(succeeded: false, cancelled: true) == .giveUp)
        #expect(TemporaryShowCancellation.afterMove(succeeded: false, cancelled: false) == .giveUp)
    }

    @Test func cancellationOnlySkipsTheClick() {
        #expect(!TemporaryShowCancellation.clicks(cancelled: true, contextStillRegistered: true))
        #expect(!TemporaryShowCancellation.clicks(cancelled: false, contextStillRegistered: false))
        #expect(TemporaryShowCancellation.clicks(cancelled: false, contextStillRegistered: true))
    }

    @Test func cancelledAfterTheMoveTheItemGoesBackThroughTheTimer() {
        // A was moved into the slot, then the operation was cancelled.
        var shown = [String]()
        if TemporaryShowCancellation.startsMove(cancelled: false) {
            // move done; cancelled now
            if TemporaryShowCancellation.afterMove(succeeded: true, cancelled: true) != .giveUp {
                shown.append("A")
            }
        }
        #expect(shown == ["A"])
        // The rehide timer (and the next click) find A and send it back.
        #expect(Plan.steps(shown: shown, clicked: "B", needsSlot: true) == [.returnToOrigin("A"), .showInSlot("B")])
    }
}
