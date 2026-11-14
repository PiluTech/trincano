//
//  NoHardcodedInterfaceTextTests.swift
//  TrincanoTests
//

import Foundation
import Testing

/// Interface text must come from the String Catalog. These APIs take text the user
/// hears (VoiceOver actions) or reads (alerts); a bare string literal there skips
/// localization (audit item L3).
struct NoHardcodedInterfaceTextTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func swiftSources() -> [URL] {
        let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent("Ice"), includingPropertiesForKeys: nil)
        return (enumerator?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
    }

    @Test func noLiteralTextInAccessibilityActionsOrAlerts() throws {
        // A literal right after the opening: `named: "`, `messageText = "`/`"""`, `informativeText = "`.
        let pattern = try NSRegularExpression(
            pattern: #"accessibilityAction\(named:\s*"|(?:messageText|informativeText)\s*=\s*""#
        )
        var offenders: [String] = []
        for file in swiftSources() {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            if pattern.firstMatch(in: text, range: range) != nil {
                offenders.append(file.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty, "literal interface text in: \(offenders)")
    }

    @Test func catalogHasTheVoiceOverAndMigrationTexts() throws {
        let url = root.appendingPathComponent("Ice/Resources/Localizable.xcstrings")
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        for key in ["Left click", "Right click"] {
            #expect(strings[key] != nil, "missing catalog key: \(key)")
        }
        #expect(strings.keys.contains { $0.contains("menu bar sections was corrupted") })
    }
}
