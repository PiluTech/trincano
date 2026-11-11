//
//  XPCPeerPolicy.swift
//  Shared
//

/// Decides which requirement an XPC endpoint places on its peer.
///
/// The decision is pure (no Security or XPC calls) so it can be tested.
/// Builds signed with a Developer ID or Apple Development certificate
/// carry a team identifier and keep the same-team requirement. Builds
/// signed with a local certificate (or ad hoc) have no team identifier,
/// so the same-team check can never pass; those fall back to requiring
/// the peer's exact signing identifier. The requirement is never dropped.
/// If reading the team identifier itself fails, the policy fails closed
/// (same-team, which never passes without a team) instead of weakening.
enum XPCPeerPolicy: Equatable {
    /// Result of reading the current process's team identifier.
    enum TeamLookup: Equatable {
        /// The signature was read and carries this team identifier.
        case team(String)
        /// The signature was read and has no team (local certificate or ad hoc).
        case none
        /// The signature could not be read.
        case failed
    }

    /// The peer must have the same team identifier and signing identifier.
    case sameTeam(signingIdentifier: String)

    /// The peer must have exactly this signing identifier.
    case signingIdentifier(String)

    /// Returns the policy for a process with the given team identifier.
    ///
    /// - Parameters:
    ///   - teamIdentifier: The team identifier of the current process,
    ///     or `nil` if it has none.
    ///   - peerSigningIdentifier: The signing identifier the peer must have.
    static func make(teamLookup: TeamLookup, peerSigningIdentifier: String) -> XPCPeerPolicy {
        switch teamLookup {
        case .team(let team):
            make(teamIdentifier: team, peerSigningIdentifier: peerSigningIdentifier)
        case .none:
            .signingIdentifier(peerSigningIdentifier)
        case .failed:
            .sameTeam(signingIdentifier: peerSigningIdentifier)
        }
    }

    static func make(teamIdentifier: String?, peerSigningIdentifier: String) -> XPCPeerPolicy {
        if let teamIdentifier, !teamIdentifier.isEmpty {
            .sameTeam(signingIdentifier: peerSigningIdentifier)
        } else {
            .signingIdentifier(peerSigningIdentifier)
        }
    }
}
