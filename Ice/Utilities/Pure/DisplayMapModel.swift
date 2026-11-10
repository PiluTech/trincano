//
//  DisplayMapModel.swift
//  Ice
//

import CoreGraphics

/// A connected display, as the settings map needs it.
struct DisplayDescriptor: Equatable {
    /// The runtime display ID (not stable across reconnections, but always
    /// present and unique while the display is connected).
    let id: UInt32
    /// The stable display UUID, if the system gave one.
    let uuid: String?
    let name: String
    /// The display frame in AppKit coordinates (y up).
    let frame: CGRect
    let hasNotch: Bool
}

/// One display in the settings map.
struct DisplayMapEntry: Equatable, Identifiable {
    let id: UInt32
    /// The display name, or "" if the system gave none.
    let name: String
    /// 1-based position among the displays, used to name an unnamed display.
    let position: Int
    /// 1-based ordinal among displays with the same name, and how many there are.
    /// `nil` when the name is unique.
    let duplicate: (ordinal: Int, count: Int)?
    let pixelSize: CGSize
    /// The rectangle in the map, in a top-left origin space.
    let rect: CGRect
    let hasNotch: Bool
    /// The key to store this display's profile under, or `nil` when the
    /// display can't have a profile (no UUID, or a UUID shared with another
    /// connected display).
    let profileKey: String?

    static func == (lhs: DisplayMapEntry, rhs: DisplayMapEntry) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.position == rhs.position
            && lhs.duplicate?.ordinal == rhs.duplicate?.ordinal
            && lhs.duplicate?.count == rhs.duplicate?.count
            && lhs.pixelSize == rhs.pixelSize && lhs.rect == rhs.rect
            && lhs.hasNotch == rhs.hasNotch && lhs.profileKey == rhs.profileKey
    }
}

enum DisplayMapModel {
    static func entries(for displays: [DisplayDescriptor], fitting size: CGSize, gap: CGFloat = 10) -> [DisplayMapEntry] {
        guard
            !displays.isEmpty,
            let first = displays.first
        else {
            return []
        }
        let union = displays.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        guard union.width > 0, union.height > 0 else {
            return []
        }
        let scale = min(size.width / union.width, size.height / union.height)
        let drawn = CGSize(width: union.width * scale, height: union.height * scale)
        let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)

        let nameCounts = Dictionary(grouping: displays.filter { !$0.name.isEmpty }, by: \.name).mapValues(\.count)
        let uuidCounts = Dictionary(grouping: displays.compactMap(\.uuid), by: { $0 }).mapValues(\.count)
        var seen = [String: Int]()

        return displays.enumerated().map { index, display in
            var duplicate: (ordinal: Int, count: Int)?
            if let count = nameCounts[display.name], count > 1 {
                seen[display.name, default: 0] += 1
                duplicate = (seen[display.name] ?? 1, count)
            }
            let f = display.frame
            var rect = CGRect(
                x: origin.x + (f.minX - union.minX) * scale,
                y: origin.y + (union.maxY - f.maxY) * scale,
                width: f.width * scale,
                height: f.height * scale
            )
            if displays.count > 1 {
                // Visual gap so neighbours don't touch. Capped so a tiny or
                // zero-sized rect never collapses to `CGRect.null`.
                let inset = max(min(gap / 2, rect.width / 4, rect.height / 4), 0)
                rect = rect.insetBy(dx: inset, dy: inset)
            }
            let key = display.uuid.flatMap { uuidCounts[$0] == 1 ? $0 : nil }
            return DisplayMapEntry(
                id: display.id,
                name: display.name,
                position: index + 1,
                duplicate: duplicate,
                pixelSize: f.size,
                rect: rect,
                hasNotch: display.hasNotch,
                profileKey: key
            )
        }
    }

    /// The selected display: the current one while it is connected, else the
    /// first connected one (the selected display was disconnected, or nothing
    /// is selected yet).
    static func effectiveSelection(current: UInt32?, connectedIDs: [UInt32]) -> UInt32? {
        if let current, connectedIDs.contains(current) {
            return current
        }
        return connectedIDs.first
    }

    /// The map only makes sense with two or more displays.
    static func shouldShowMap(displayCount: Int) -> Bool {
        displayCount >= 2
    }
}
