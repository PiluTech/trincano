//
//  ReplacementTargetPlanTests.swift
//  TrincanoTests
//

import Testing

struct ReplacementTargetPlanTests {
    private let id = "br.com.pilutech.trincano"

    private func verdict(
        exists: Bool = true,
        symlink: Bool = false,
        bundleID: String? = "br.com.pilutech.trincano"
    ) -> ReplacementTargetPlan.Verdict {
        ReplacementTargetPlan.evaluate(
            exists: exists,
            isSymbolicLink: symlink,
            bundleIdentifier: bundleID,
            expectedBundleIdentifier: id
        )
    }

    @Test func missingDestinationIsSafeToCreate() {
        #expect(verdict(exists: false, bundleID: nil) == .safe)
    }

    @Test func sameAppIsSafeToReplace() {
        #expect(verdict() == .safe)
    }

    @Test func symlinkIsRefusedEvenWithMatchingIdentifier() {
        // A link to another folder would make `rm -rf` hit whatever it points at.
        #expect(verdict(symlink: true) == .refusedSymlink)
    }

    @Test func danglingSymlinkIsRefused() {
        // `fileExists` follows links, so a broken link reports "does not exist".
        #expect(verdict(exists: false, symlink: true, bundleID: nil) == .refusedSymlink)
    }

    @Test func otherAppIsRefused() {
        #expect(verdict(bundleID: "com.example.Other") == .refusedOtherApp)
    }

    @Test func unreadableBundleIsRefused() {
        #expect(verdict(bundleID: nil) == .refusedOtherApp)
    }

    @Test func missingExpectedIdentifierRefusesAnExistingDestination() {
        let result = ReplacementTargetPlan.evaluate(
            exists: true,
            isSymbolicLink: false,
            bundleIdentifier: nil,
            expectedBundleIdentifier: nil
        )
        #expect(result == .refusedOtherApp)
    }
}
