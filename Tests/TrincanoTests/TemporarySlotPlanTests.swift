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

        async let first: Void = queue.run {
            log.add("A start")
            await Task.yield()
            await Task.yield()
            log.add("A end")
        }
        async let second: Void = queue.run {
            log.add("B start")
            await Task.yield()
            log.add("B end")
        }
        _ = await (first, second)

        #expect(log.entries == ["A start", "A end", "B start", "B end"])
    }

    @Test func aStuckOperationDoesNotBlockTheNextOne() async {
        var timeouts = 0
        let queue = SerialAsyncQueue(timeout: .milliseconds(50), onTimeout: { timeouts += 1 })
        let log = Log()

        async let stuck: Void = queue.run {
            log.add("stuck start")
            try? await Task.sleep(for: .milliseconds(400))
            log.add("stuck end")
        }
        async let next: Void = queue.run {
            log.add("next")
        }
        _ = await (stuck, next)

        #expect(log.entries == ["stuck start", "next", "stuck end"])
        #expect(timeouts == 1)
    }

    @Test func runsInSubmissionOrderAndReturnsTheValue() async {
        let queue = SerialAsyncQueue()
        let value = await queue.run { 42 }
        #expect(value == 42)
    }

    @MainActor
    final class Log {
        var entries = [String]()
        func add(_ entry: String) { entries.append(entry) }
    }
}
