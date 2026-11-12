//
//  MoveToApplicationsPlan.swift
//  Ice
//

/// Decides whether the app should offer to move itself to the Applications
/// folder, and whether the old copy may be removed afterwards.
///
/// The decision is pure so it can be tested without moving anything.
enum MoveToApplicationsPlan {
    /// What the app should do at launch.
    enum Decision: Equatable {
        /// Already installed (or a development build): do nothing.
        case stay
        /// Show the "Move to Applications" alert.
        case offer(deleteOldCopy: Bool)
    }

    /// Folders where an installed app is considered in place.
    static let installDirectories = ["/Applications/", "/System/Applications/"]

    /// Marker Gatekeeper puts in the path of a translocated app.
    static let translocationMarker = "/AppTranslocation/"

    /// Returns whether the bundle path is translocated by Gatekeeper.
    static func isTranslocated(_ path: String) -> Bool {
        path.contains(translocationMarker)
    }

    /// Returns whether the path is inside an installation directory: the
    /// system `/Applications` (any depth) or the user's `~/Applications`.
    static func isInstalled(_ path: String, homeDirectory: String) -> Bool {
        if isTranslocated(path) {
            return false
        }
        let userApplications = homeDirectory.hasSuffix("/")
            ? homeDirectory + "Applications/"
            : homeDirectory + "/Applications/"
        return (installDirectories + [userApplications]).contains { path.hasPrefix($0) }
    }

    /// Returns whether the path looks like a build output, which developers
    /// run in place on purpose.
    static func isDevelopmentBuild(_ path: String) -> Bool {
        path.contains("/DerivedData/") || path.contains("/Build/Products/")
    }

    /// Returns whether the old copy can be deleted after the move. A
    /// translocated copy is a read-only mirror and a disk image is read-only,
    /// so only a normal folder (such as Downloads) qualifies.
    static func canDeleteOldCopy(at path: String) -> Bool {
        !isTranslocated(path) && !path.hasPrefix("/Volumes/")
    }

    /// Decides what to do.
    ///
    /// - Parameters:
    ///   - bundlePath: Path of the running app bundle.
    ///   - homeDirectory: The user's home directory.
    ///   - userDeclined: Whether the user already chose "Not now".
    static func decide(bundlePath: String, homeDirectory: String, userDeclined: Bool) -> Decision {
        if userDeclined || isDevelopmentBuild(bundlePath) || isInstalled(bundlePath, homeDirectory: homeDirectory) {
            return .stay
        }
        return .offer(deleteOldCopy: canDeleteOldCopy(at: bundlePath))
    }
}
