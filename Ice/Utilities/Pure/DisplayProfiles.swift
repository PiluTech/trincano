//
//  DisplayProfiles.swift
//  Ice
//

import Foundation

/// How the hidden section is shown on one display.
enum DisplayBarMode: String, Codable, CaseIterable {
    /// Follow the global "Use Trincano Bar" setting.
    case followGlobal
    /// Always use the Trincano Bar on this display.
    case bar
    /// Always expand the menu bar inline on this display.
    case inline
}

/// Per-display settings, keyed by the display's UUID (stable across
/// reconnections, unlike the numeric display ID).
struct DisplayProfiles: Codable, Equatable {
    private(set) var modes = [String: DisplayBarMode]()

    func mode(for uuid: String?) -> DisplayBarMode {
        uuid.flatMap { modes[$0] } ?? .followGlobal
    }

    /// The mode that applies at runtime to a connected display.
    ///
    /// A display without a UUID, or whose UUID is shared with another connected
    /// display, can't have its own profile (the settings UI says it follows the
    /// global setting), so any profile stored under that UUID is ignored.
    func effectiveMode(for uuid: String?, connectedUUIDs: [String?]) -> DisplayBarMode {
        guard let uuid, connectedUUIDs.filter({ $0 == uuid }).count <= 1 else {
            return .followGlobal
        }
        return mode(for: uuid)
    }

    mutating func set(_ mode: DisplayBarMode, for uuid: String) {
        if mode == .followGlobal {
            modes.removeValue(forKey: uuid)
        } else {
            modes[uuid] = mode
        }
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes stored data. Corrupt or missing data gives empty profiles; an
    /// entry with an unknown mode (from a newer version) or a value of the
    /// wrong type is dropped on its own, keeping the valid ones.
    static func decode(_ data: Data?) -> DisplayProfiles {
        guard
            let data,
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let stored = root["modes"] as? [String: Any]
        else {
            return DisplayProfiles()
        }
        var profiles = DisplayProfiles()
        for (uuid, value) in stored {
            if let rawMode = value as? String, let mode = DisplayBarMode(rawValue: rawMode) {
                profiles.set(mode, for: uuid)
            }
        }
        return profiles
    }
}

enum DisplayBarPolicy {
    /// Returns whether the Trincano Bar is used on a display.
    static func useBar(global: Bool, mode: DisplayBarMode) -> Bool {
        switch mode {
        case .followGlobal: global
        case .bar: true
        case .inline: false
        }
    }
}
