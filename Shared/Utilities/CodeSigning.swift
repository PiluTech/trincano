//
//  CodeSigning.swift
//  Shared
//

import Security
import XPC

enum CodeSigningInfo {
    /// The team identifier of the current process. `.none` only when the
    /// signature was read and has no team (local certificate or ad hoc);
    /// any failure reading it is `.failed` so the policy fails closed.
    static var teamLookup: XPCPeerPolicy.TeamLookup {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return .failed
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return .failed
        }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else {
            return .failed
        }
        if let team = dict[kSecCodeInfoTeamIdentifier as String] as? String {
            return .team(team)
        }
        return .none
    }
}

@available(macOS 26.0, *)
extension XPCPeerRequirement {
    /// Returns the requirement for a peer whose signing identifier is
    /// `signingIdentifier`, chosen by ``XPCPeerPolicy``.
    static func trincanoPeer(signingIdentifier: String) -> XPCPeerRequirement {
        switch XPCPeerPolicy.make(
            teamLookup: CodeSigningInfo.teamLookup,
            peerSigningIdentifier: signingIdentifier
        ) {
        case .sameTeam(let identifier):
            return .isFromSameTeam(andMatchesSigningIdentifier: identifier)
        case .signingIdentifier(let identifier):
            var requirements = XPCDictionary()
            requirements["signing-identifier"] = identifier
            return XPCPeerRequirement(lightweightCodeRequirements: requirements)
        }
    }
}
