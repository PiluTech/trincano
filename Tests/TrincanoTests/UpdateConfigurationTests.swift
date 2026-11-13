//
//  UpdateConfigurationTests.swift
//  TrincanoTests
//

import Foundation
import Testing

/// Guards the Sparkle configuration: consent first, HTTPS only, signed updates.
struct UpdateConfigurationTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Build number (`CFBundleVersion`) of the previous release, v0.13.0.
    private static let previousBuild = 1130

    private func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("Ice/Resources/Info.plist"))
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(object as? [String: Any])
    }

    private func projectValues(for key: String) throws -> Set<String> {
        let text = try String(contentsOf: Self.root.appendingPathComponent("Ice.xcodeproj/project.pbxproj"), encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: "\\b\(key) = \"?([^\";\\s]+)\"?;")
        let range = NSRange(text.startIndex..., in: text)
        return Set(pattern.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        })
    }

    @Test func neverEnablesChecksWithoutAsking() throws {
        // Absent key: Sparkle asks on the second launch. `true` would skip the
        // question and `false` would never ask.
        #expect(try infoPlist()["SUEnableAutomaticChecks"] == nil)
    }

    @Test func feedIsTheHTTPSAppcastOfTheGitHubRelease() throws {
        let feed = try #require(try infoPlist()["SUFeedURL"] as? String)
        #expect(feed == "https://github.com/PiluTech/trincano/releases/latest/download/appcast.xml")
        #expect(URL(string: feed)?.scheme == "https")
    }

    @Test func publicKeyIsAnEd25519Key() throws {
        let key = try #require(try infoPlist()["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: key)?.count == 32)
    }

    @Test func checksDailyWithoutSystemProfile() throws {
        let plist = try infoPlist()
        #expect(plist["SUScheduledCheckInterval"] as? Int == 86400)
        #expect(plist["SUEnableSystemProfiling"] as? Bool == false)
    }

    @Test func requiresASignedFeedAndVerifiesBeforeExtraction() throws {
        // Sparkle refuses SURequireSignedFeed unless SUVerifyUpdateBeforeExtraction is also on.
        let plist = try infoPlist()
        #expect(plist["SURequireSignedFeed"] as? Bool == true)
        #expect(plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
    }

    @Test func sparkleIsPinnedToAnExactVersion() throws {
        let text = try String(contentsOf: Self.root.appendingPathComponent("Ice.xcodeproj/project.pbxproj"), encoding: .utf8)
        let range = try #require(text.range(of: "sparkle-project/Sparkle\""))
        let block = String(text[range.upperBound...].prefix(200))
        #expect(block.contains("kind = exactVersion"))
    }

    @Test func currentBuildIsNewerThanThePreviousRelease() throws {
        let builds = try projectValues(for: "CURRENT_PROJECT_VERSION").compactMap(Int.init)
        let appBuild = try #require(builds.max())
        #expect(appBuild > Self.previousBuild)
    }

    @Test func marketingVersionIsTheNextRelease() throws {
        #expect(try projectValues(for: "MARKETING_VERSION").contains("0.13.1"))
    }
}
