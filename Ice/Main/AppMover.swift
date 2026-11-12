//
//  AppMover.swift
//  Ice
//

import AppKit
import OSLog

/// Offers to move the app to the Applications folder when it runs from
/// somewhere else (Downloads, a disk image, Gatekeeper translocation).
///
/// Running from /Applications is also what lets Sparkle replace the app.
/// The decision lives in `MoveToApplicationsPlan` (tested); this type only
/// does the alert, the copy and the relaunch.
@MainActor
enum AppMover {
    private static let declinedKey = "MoveToApplicationsDeclined"
    private static let logger = Logger(category: "AppMover")

    /// Shows the alert when the app is outside Applications.
    static func offerIfNeeded() {
        let bundleURL = Bundle.main.bundleURL
        let decision = MoveToApplicationsPlan.decide(
            bundlePath: bundleURL.path,
            homeDirectory: NSHomeDirectory(),
            userDeclined: UserDefaults.standard.bool(forKey: declinedKey)
        )
        guard case .offer(let deleteOldCopy) = decision else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "Move Trincano to the Applications folder?")
        alert.informativeText = String(
            localized: "Trincano is running from outside the Applications folder. Moving it there keeps it in place and lets updates install."
        )
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Not Now"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true, forKey: declinedKey)
            return
        }

        // Fixed name: a renamed bundle must never make us replace another app.
        let destination = URL(fileURLWithPath: "/Applications/Trincano.app")
        do {
            try copy(from: bundleURL, to: destination)
        } catch {
            logger.error("Could not move to Applications: \(String(describing: error))")
            let failure = NSAlert()
            failure.messageText = String(localized: "Could not move Trincano")
            failure.informativeText = String(
                localized: "Drag Trincano to the Applications folder yourself and open it from there."
            )
            failure.runModal()
            return
        }
        relaunch(from: destination, removing: deleteOldCopy ? bundleURL : nil)
    }

    // MARK: Copy

    private enum CopyError: Error {
        case failed
        case refused(ReplacementTargetPlan.Verdict)
    }

    /// Early check for the unprivileged path (a clear refusal before touching
    /// anything). It does NOT protect the administrator step: the password
    /// prompt comes later, so that step repeats the same rules inside its own
    /// script (`PrivilegedReplaceScript`), right before `rm`/`ditto`.
    private static func verifyDestination(_ destination: URL) throws {
        var info = stat()
        let exists = lstat(destination.path, &info) == 0
        let isSymbolicLink = exists && (info.st_mode & S_IFMT) == S_IFLNK
        var isBundleComplete = false
        var bundleIdentifier: String?
        if exists, !isSymbolicLink, let bundle = Bundle(url: destination) {
            bundleIdentifier = bundle.bundleIdentifier
            isBundleComplete = bundle.executableURL.map {
                FileManager.default.fileExists(atPath: $0.path)
            } ?? false
        }
        let verdict = ReplacementTargetPlan.evaluate(
            exists: exists,
            isSymbolicLink: isSymbolicLink,
            isBundleComplete: isBundleComplete,
            bundleIdentifier: bundleIdentifier,
            expectedBundleIdentifier: Bundle.main.bundleIdentifier
        )
        if verdict != .safe {
            throw CopyError.refused(verdict)
        }
    }

    /// Copies the bundle, replacing an older copy. Asks for the password only
    /// when the plain copy is not permitted.
    private static func copy(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        // Only replace a complete copy of this same app (same bundle
        // identifier), and never through a symbolic link.
        try verifyDestination(destination)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.trashItem(at: destination, resultingItemURL: nil)
            }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            try copyWithAdministratorPrivileges(from: source, to: destination)
        }
        // The copy was already approved by Gatekeeper (it is the running app),
        // so drop the quarantine flag to avoid a second translocation.
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", destination.path])
    }

    private static func copyWithAdministratorPrivileges(from source: URL, to destination: URL) throws {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw CopyError.failed
        }
        // The checks are part of the script itself, so they run as
        // administrator right before the `rm`/`ditto`, after the password.
        let shell = PrivilegedReplaceScript.build(
            source: source.path,
            destination: destination.path,
            expectedBundleIdentifier: bundleIdentifier
        )
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")
        script?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            // For `do shell script`, the error number is the script's exit status.
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int).flatMap(Int32.init(exactly:))
            if let number, let verdict = ReplacementTargetPlan.Verdict(scriptExitCode: number) {
                throw CopyError.refused(verdict)
            }
            throw CopyError.failed
        }
        if !FileManager.default.fileExists(atPath: destination.path) {
            throw CopyError.failed
        }
    }

    // MARK: Relaunch

    /// Starts the copy from Applications after this process exits, then
    /// removes the old copy (when allowed).
    private static func relaunch(from destination: URL, removing oldCopy: URL?) {
        // Positional arguments keep the paths out of the shell's parsing.
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if [ -n "$3" ]; then rm -rf "$3"; fi
        open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", script, "sh",
            String(ProcessInfo.processInfo.processIdentifier),
            destination.path,
            oldCopy.map { $0.pathExtension == "app" ? $0.path : "" } ?? "",
        ]
        do {
            try process.run()
        } catch {
            logger.error("Could not relaunch: \(error.localizedDescription)")
            return
        }
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
