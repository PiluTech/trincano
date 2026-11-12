//
//  ReplacementTargetPlan.swift
//  Ice
//

/// Decides whether an existing destination may be replaced when the app moves
/// itself to the Applications folder.
///
/// The decision is pure so it can be tested without touching the disk. The
/// caller reads the facts (never following links). The same rules run twice:
/// in the app (early, for a clear message and the unprivileged copy) and
/// inside the privileged script (`PrivilegedReplaceScript`), which is the
/// check that counts because it runs right before the destructive commands.
enum ReplacementTargetPlan {
    enum Verdict: Equatable {
        /// Nothing there, or this same complete app: safe to create or replace.
        case safe
        /// The destination is a symbolic link; removing or copying over it
        /// could hit whatever it points at.
        case refusedSymlink
        /// The destination is a complete bundle of another app.
        case refusedOtherApp
        /// The destination exists but is not a complete bundle (no readable
        /// `Info.plist`, or the executable it names is missing).
        case refusedIncompleteBundle

        /// Exit status the privileged script uses for this verdict.
        var scriptExitCode: Int32? {
            switch self {
            case .safe: nil
            case .refusedSymlink: 10
            case .refusedOtherApp: 11
            case .refusedIncompleteBundle: 12
            }
        }

        init?(scriptExitCode: Int32) {
            switch scriptExitCode {
            case 10: self = .refusedSymlink
            case 11: self = .refusedOtherApp
            case 12: self = .refusedIncompleteBundle
            default: return nil
            }
        }
    }

    /// - Parameters:
    ///   - exists: Whether anything exists at the path.
    ///   - isSymbolicLink: Whether the path itself is a symbolic link.
    ///   - isBundleComplete: Whether `Contents/Info.plist` is readable and the
    ///     executable it names exists.
    ///   - bundleIdentifier: Bundle identifier read from the destination.
    ///   - expectedBundleIdentifier: This app's bundle identifier.
    static func evaluate(
        exists: Bool,
        isSymbolicLink: Bool,
        isBundleComplete: Bool,
        bundleIdentifier: String?,
        expectedBundleIdentifier: String?
    ) -> Verdict {
        if isSymbolicLink {
            return .refusedSymlink
        }
        guard exists else {
            return .safe
        }
        guard isBundleComplete else {
            return .refusedIncompleteBundle
        }
        guard let expectedBundleIdentifier, bundleIdentifier == expectedBundleIdentifier else {
            return .refusedOtherApp
        }
        return .safe
    }
}
