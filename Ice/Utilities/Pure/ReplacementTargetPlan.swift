//
//  ReplacementTargetPlan.swift
//  Ice
//

/// Decides whether an existing destination may be replaced when the app moves
/// itself to the Applications folder.
///
/// The decision is pure so it can be tested without touching the disk. The
/// caller reads the facts (`lstat`-style, never following links) and must
/// evaluate them again right before each destructive step, since the
/// destination can change between the first check and the password prompt.
enum ReplacementTargetPlan {
    enum Verdict: Equatable {
        /// Nothing there, or this same app: safe to create or replace.
        case safe
        /// The destination is a symbolic link; removing or copying over it
        /// could hit whatever it points at.
        case refusedSymlink
        /// The destination is not this app (other or unreadable bundle).
        case refusedOtherApp
    }

    /// - Parameters:
    ///   - exists: Whether anything exists at the path, links not followed
    ///     (a dangling symlink counts as existing).
    ///   - isSymbolicLink: Whether the path itself is a symbolic link.
    ///   - bundleIdentifier: Bundle identifier read from the destination.
    ///   - expectedBundleIdentifier: This app's bundle identifier.
    static func evaluate(
        exists: Bool,
        isSymbolicLink: Bool,
        bundleIdentifier: String?,
        expectedBundleIdentifier: String?
    ) -> Verdict {
        if isSymbolicLink {
            return .refusedSymlink
        }
        guard exists else {
            return .safe
        }
        guard let expectedBundleIdentifier, bundleIdentifier == expectedBundleIdentifier else {
            return .refusedOtherApp
        }
        return .safe
    }
}
