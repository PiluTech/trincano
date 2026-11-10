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
}
