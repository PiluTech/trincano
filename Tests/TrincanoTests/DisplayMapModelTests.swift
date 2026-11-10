//
//  DisplayMapModelTests.swift
//  TrincanoTests
//

import CoreGraphics
import Testing

struct DisplayMapModelTests {
    private func display(
        _ id: UInt32,
        _ name: String,
        uuid: String? = nil,
        frame: CGRect,
        notch: Bool = false
    ) -> DisplayDescriptor {
        DisplayDescriptor(id: id, uuid: uuid ?? "UUID-\(id)", name: name, frame: frame, hasNotch: notch)
    }

    private let mac = CGRect(x: 0, y: 0, width: 1470, height: 956)
    private let studio = CGRect(x: 1470, y: 0, width: 2560, height: 1440)
    private let map = CGSize(width: 600, height: 150)

    @Test func noDisplaysGiveNoEntries() {
        #expect(DisplayMapModel.entries(for: [], fitting: map).isEmpty)
    }

    @Test func entriesKeepTheInputOrderAndRuntimeIDs() {
        let entries = DisplayMapModel.entries(
            for: [display(7, "A", frame: mac), display(3, "B", frame: studio)], fitting: map
        )
        #expect(entries.map(\.id) == [7, 3])
        #expect(entries.map(\.position) == [1, 2])
    }

    @Test func everyRectFitsInsideTheMap() {
        let entries = DisplayMapModel.entries(
            for: [display(1, "A", frame: mac), display(2, "B", frame: studio)], fitting: map
        )
        for entry in entries {
            #expect(CGRect(origin: .zero, size: map).contains(entry.rect), "\(entry.rect)")
        }
    }

    @Test func rectsKeepTheSystemArrangementAndDoNotOverlap() {
        let entries = DisplayMapModel.entries(
            for: [display(1, "A", frame: mac), display(2, "B", frame: studio)], fitting: map
        )
        #expect(entries[0].rect.maxX <= entries[1].rect.minX)
        // Same size ratio as the real displays, within the visual gap.
        let ratio = entries[1].rect.width / entries[0].rect.width
        #expect(abs(ratio - 2560.0 / 1470.0) < 0.1)
    }

    @Test func aDisplayAboveAnotherIsDrawnAbove() {
        let top = CGRect(x: 0, y: 956, width: 1470, height: 956)
        let entries = DisplayMapModel.entries(
            for: [display(1, "Bottom", frame: mac), display(2, "Top", frame: top)], fitting: map
        )
        // Map space has its origin at the top-left (y down).
        #expect(entries[1].rect.maxY <= entries[0].rect.minY)
    }

    @Test func aSingleDisplayIsScaledToFillTheMap() {
        let entries = DisplayMapModel.entries(for: [display(1, "A", frame: mac)], fitting: map)
        #expect(entries.count == 1)
        #expect(abs(entries[0].rect.height - map.height) < 0.001)
    }

    @Test func sameNamesGetOrdinalsAndUniqueNamesDoNot() {
        let entries = DisplayMapModel.entries(
            for: [
                display(1, "LG", frame: mac),
                display(2, "Studio", frame: studio),
                display(3, "LG", frame: CGRect(x: 4030, y: 0, width: 1920, height: 1080)),
            ],
            fitting: map
        )
        #expect(entries[0].duplicate?.ordinal == 1 && entries[0].duplicate?.count == 2)
        #expect(entries[2].duplicate?.ordinal == 2 && entries[2].duplicate?.count == 2)
        #expect(entries[1].duplicate == nil)
    }

    @Test func emptyNameKeepsAnEmptyNameAndAPosition() {
        let entries = DisplayMapModel.entries(for: [display(1, "", frame: mac)], fitting: map)
        #expect(entries[0].name.isEmpty)
        #expect(entries[0].position == 1)
        #expect(entries[0].duplicate == nil)
    }

    @Test func twoUnnamedDisplaysAreNotTreatedAsSameName() {
        let entries = DisplayMapModel.entries(
            for: [display(1, "", frame: mac), display(2, "", frame: studio)], fitting: map
        )
        #expect(entries.allSatisfy { $0.duplicate == nil })
    }

    @Test func missingUUIDHasNoProfileKey() {
        var d = display(1, "A", frame: mac)
        d = DisplayDescriptor(id: d.id, uuid: nil, name: d.name, frame: d.frame, hasNotch: false)
        #expect(DisplayMapModel.entries(for: [d], fitting: map)[0].profileKey == nil)
    }

    @Test func sharedUUIDHasNoProfileKeyForAnyOfThem() {
        let entries = DisplayMapModel.entries(
            for: [display(1, "A", uuid: "SAME", frame: mac), display(2, "B", uuid: "SAME", frame: studio)],
            fitting: map
        )
        #expect(entries.allSatisfy { $0.profileKey == nil })
    }

    @Test func uniqueUUIDIsTheProfileKey() {
        let entries = DisplayMapModel.entries(for: [display(1, "A", uuid: "U1", frame: mac)], fitting: map)
        #expect(entries[0].profileKey == "U1")
    }

    @Test func pixelSizeAndNotchComeFromTheDisplay() {
        let entries = DisplayMapModel.entries(for: [display(1, "A", frame: mac, notch: true)], fitting: map)
        #expect(entries[0].pixelSize == mac.size)
        #expect(entries[0].hasNotch)
    }

    @Test func threeDisplaysKeepOrderFitAndDoNotOverlap() {
        let third = CGRect(x: 4030, y: 0, width: 1920, height: 1080)
        let entries = DisplayMapModel.entries(
            for: [display(1, "A", frame: mac), display(2, "B", frame: studio), display(3, "C", frame: third)],
            fitting: map
        )
        #expect(entries.map(\.position) == [1, 2, 3])
        for entry in entries {
            #expect(CGRect(origin: .zero, size: map).contains(entry.rect))
        }
        #expect(entries[0].rect.maxX <= entries[1].rect.minX)
        #expect(entries[1].rect.maxX <= entries[2].rect.minX)
    }

    @Test func degenerateFittingNeverProducesANullRect() {
        let frames = [display(1, "A", frame: mac), display(2, "B", frame: studio)]
        for size in [CGSize.zero, CGSize(width: 0, height: 150), CGSize(width: 5, height: 5)] {
            for entry in DisplayMapModel.entries(for: frames, fitting: size) {
                #expect(!entry.rect.isNull, "\(size) -> \(entry.rect)")
                #expect(!entry.rect.isInfinite)
                #expect(entry.rect.width >= 0 && entry.rect.height >= 0)
            }
        }
    }

    @Test func zeroSizedDisplayFrameGivesNoEntries() {
        #expect(DisplayMapModel.entries(for: [display(1, "A", frame: .zero)], fitting: map).isEmpty)
    }

    @Test func selectionKeepsTheCurrentDisplayWhileItIsConnected() {
        #expect(DisplayMapModel.effectiveSelection(current: 2, connectedIDs: [1, 2, 3]) == 2)
    }

    @Test func selectionFallsBackToTheFirstWhenTheSelectedDisplayIsGone() {
        #expect(DisplayMapModel.effectiveSelection(current: 9, connectedIDs: [4, 5]) == 4)
        #expect(DisplayMapModel.effectiveSelection(current: nil, connectedIDs: [4, 5]) == 4)
    }

    @Test func selectionIsNilWithoutDisplays() {
        #expect(DisplayMapModel.effectiveSelection(current: 1, connectedIDs: []) == nil)
    }

    @Test func mapIsShownOnlyWithTwoOrMoreDisplays() {
        #expect(!DisplayMapModel.shouldShowMap(displayCount: 0))
        #expect(!DisplayMapModel.shouldShowMap(displayCount: 1))
        #expect(DisplayMapModel.shouldShowMap(displayCount: 2))
    }
}
