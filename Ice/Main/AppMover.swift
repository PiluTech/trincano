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
            logger.error("Could not move to Applications: \(error.localizedDescription)")
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
        case destinationIsAnotherApp
    }

    /// Copies the bundle, replacing an older copy. Asks for the password only
    /// when the plain copy is not permitted.
    private static func copy(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        // Only replace an existing copy of this same app (same bundle identifier).
        if
            fileManager.fileExists(atPath: destination.path),
            Bundle(url: destination)?.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            throw CopyError.destinationIsAnotherApp
        }
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
        func quoted(_ path: String) -> String {
            "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let shell = "/bin/rm -rf \(quoted(destination.path)) && /usr/bin/ditto \(quoted(source.path)) \(quoted(destination.path))"
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")
        script?.executeAndReturnError(&errorInfo)
        if errorInfo != nil || !FileManager.default.fileExists(atPath: destination.path) {
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
