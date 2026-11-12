//
//  ReplacementTargetPlanTests.swift
//  TrincanoTests
//

import Foundation
import Testing

struct ReplacementTargetPlanTests {
    private let id = "br.com.pilutech.trincano"

    private func verdict(
        exists: Bool = true,
        symlink: Bool = false,
        bundleID: String? = "br.com.pilutech.trincano",
        complete: Bool = true
    ) -> ReplacementTargetPlan.Verdict {
        ReplacementTargetPlan.evaluate(
            exists: exists,
            isSymbolicLink: symlink,
            isBundleComplete: complete,
            bundleIdentifier: bundleID,
            expectedBundleIdentifier: id
        )
    }

    @Test func missingDestinationIsSafeToCreate() {
        #expect(verdict(exists: false, bundleID: nil, complete: false) == .safe)
    }

    @Test func sameAppIsSafeToReplace() {
        #expect(verdict() == .safe)
    }

    @Test func symlinkIsRefusedEvenWithMatchingIdentifier() {
        #expect(verdict(symlink: true) == .refusedSymlink)
    }

    @Test func danglingSymlinkIsRefused() {
        #expect(verdict(exists: false, symlink: true, bundleID: nil, complete: false) == .refusedSymlink)
    }

    @Test func otherAppIsRefused() {
        #expect(verdict(bundleID: "com.example.Other") == .refusedOtherApp)
    }

    @Test func partialBundleHasItsOwnReason() {
        #expect(verdict(bundleID: nil, complete: false) == .refusedIncompleteBundle)
        #expect(verdict(complete: false) == .refusedIncompleteBundle)
    }

    @Test func missingExpectedIdentifierRefusesAnExistingDestination() {
        let result = ReplacementTargetPlan.evaluate(
            exists: true,
            isSymbolicLink: false,
            isBundleComplete: true,
            bundleIdentifier: nil,
            expectedBundleIdentifier: nil
        )
        #expect(result == .refusedOtherApp)
    }

    @Test func exitCodesAreDistinctAndMapBack() {
        let verdicts: [ReplacementTargetPlan.Verdict] = [.refusedSymlink, .refusedOtherApp, .refusedIncompleteBundle]
        let codes = verdicts.compactMap(\.scriptExitCode)
        #expect(Set(codes).count == 3)
        for verdict in verdicts {
            #expect(ReplacementTargetPlan.Verdict(scriptExitCode: verdict.scriptExitCode ?? -1) == verdict)
        }
        #expect(ReplacementTargetPlan.Verdict.safe.scriptExitCode == nil)
        #expect(ReplacementTargetPlan.Verdict(scriptExitCode: 1) == nil)
    }
}

/// Runs the generated script as the current user against temporary folders
/// (never as administrator, never outside the temporary directory).
struct PrivilegedReplaceScriptTests {
    private let id = "br.com.pilutech.trincano"

    private func makeSandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("trincano-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func makeBundle(
        at url: URL,
        bundleID: String? = "br.com.pilutech.trincano",
        executable: String? = "Trincano",
        marker: String = "new"
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        var plist: [String: Any] = [:]
        if let bundleID { plist["CFBundleIdentifier"] = bundleID }
        if let executable {
            plist["CFBundleExecutable"] = executable
            fm.createFile(atPath: url.appendingPathComponent("Contents/MacOS/\(executable)").path, contents: Data())
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Contents/Info.plist"))
        try Data(marker.utf8).write(to: url.appendingPathComponent("Contents/marker"))
        return url
    }

    private func run(source: URL, destination: URL) throws -> Int32 {
        let script = PrivilegedReplaceScript.build(
            source: source.path,
            destination: destination.path,
            expectedBundleIdentifier: id
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private func marker(_ bundle: URL) -> String? {
        try? String(contentsOf: bundle.appendingPathComponent("Contents/marker"), encoding: .utf8)
    }

    @Test func createsWhenDestinationIsMissing() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = dir.appendingPathComponent("dest.app")
        #expect(try run(source: source, destination: destination) == 0)
        #expect(marker(destination) == "new")
    }

    @Test func replacesTheSameAppWithAFullBundle() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = try makeBundle(at: dir.appendingPathComponent("dest.app"), marker: "old")
        #expect(try run(source: source, destination: destination) == 0)
        #expect(marker(destination) == "new")
    }

    @Test func refusesSymlinkAndKeepsTheTarget() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let real = try makeBundle(at: dir.appendingPathComponent("real.app"), marker: "keep")
        let destination = dir.appendingPathComponent("dest.app")
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: real)
        #expect(try run(source: source, destination: destination) == ReplacementTargetPlan.Verdict.refusedSymlink.scriptExitCode)
        #expect(marker(real) == "keep")
    }

    @Test func refusesDanglingSymlink() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = dir.appendingPathComponent("dest.app")
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: dir.appendingPathComponent("nowhere"))
        #expect(try run(source: source, destination: destination) == ReplacementTargetPlan.Verdict.refusedSymlink.scriptExitCode)
    }

    @Test func refusesAnotherApp() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = try makeBundle(at: dir.appendingPathComponent("dest.app"), bundleID: "com.example.Other", marker: "keep")
        #expect(try run(source: source, destination: destination) == ReplacementTargetPlan.Verdict.refusedOtherApp.scriptExitCode)
        #expect(marker(destination) == "keep")
    }

    @Test func refusesPartialBundles() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let code = ReplacementTargetPlan.Verdict.refusedIncompleteBundle.scriptExitCode

        // Executable missing.
        let noExecutable = try makeBundle(at: dir.appendingPathComponent("a.app"), executable: "Gone", marker: "keep")
        try FileManager.default.removeItem(at: noExecutable.appendingPathComponent("Contents/MacOS/Gone"))
        #expect(try run(source: source, destination: noExecutable) == code)
        #expect(marker(noExecutable) == "keep")

        // Info.plist missing.
        let noPlist = try makeBundle(at: dir.appendingPathComponent("b.app"), marker: "keep")
        try FileManager.default.removeItem(at: noPlist.appendingPathComponent("Contents/Info.plist"))
        #expect(try run(source: source, destination: noPlist) == code)
        #expect(marker(noPlist) == "keep")

        // Empty folder.
        let empty = dir.appendingPathComponent("c.app")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(try run(source: source, destination: empty) == code)
    }

    @Test func quotesAwkwardPaths() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("it's src.app"))
        let destination = dir.appendingPathComponent("a b; touch pwned.app")
        #expect(try run(source: source, destination: destination) == 0)
        #expect(marker(destination) == "new")
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("pwned.app").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("pwned").path))
    }

    @Test func removesTheOldCopyOnlyAfterTheNewOneIsBuilt() {
        let script = PrivilegedReplaceScript.build(source: "/s", destination: "/d", expectedBundleIdentifier: id)
        let ditto = script.range(of: "/usr/bin/ditto")
        let check = script.range(of: "[ -L")
        let rm = script.range(of: "/bin/rm -rf \"$dest\"")
        let mv = script.range(of: "/bin/mv")
        #expect(ditto != nil && check != nil && rm != nil && mv != nil)
        if let ditto, let check, let rm, let mv {
            #expect(ditto.lowerBound < check.lowerBound)
            #expect(check.lowerBound < rm.lowerBound)
            #expect(rm.lowerBound < mv.lowerBound)
        }
    }

    @Test func failedCopyLeavesTheInstalledAppAndNoLeftovers() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missingSource = dir.appendingPathComponent("nothing.app")
        let destination = try makeBundle(at: dir.appendingPathComponent("dest.app"), marker: "keep")
        let status = try run(source: missingSource, destination: destination)
        #expect(status != 0)
        #expect(ReplacementTargetPlan.Verdict(scriptExitCode: status) == nil)
        #expect(marker(destination) == "keep")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names == ["dest.app"])
    }

    @Test func refusalLeavesNoTemporaryFolder() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = try makeBundle(at: dir.appendingPathComponent("dest.app"), bundleID: "com.example.Other")
        _ = try run(source: source, destination: destination)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(names == ["dest.app", "src.app"])
    }

    @Test func successLeavesNoTemporaryFolder() throws {
        let dir = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = try makeBundle(at: dir.appendingPathComponent("src.app"))
        let destination = try makeBundle(at: dir.appendingPathComponent("dest.app"), marker: "old")
        #expect(try run(source: source, destination: destination) == 0)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(names == ["dest.app", "src.app"])
    }
}
