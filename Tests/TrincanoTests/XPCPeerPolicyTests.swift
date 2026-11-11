//
//  XPCPeerPolicyTests.swift
//  TrincanoTests
//

import Testing

struct XPCPeerPolicyTests {
    private let peer = "br.com.pilutech.trincano"

    @Test func teamIdentifierKeepsSameTeamRequirement() {
        let policy = XPCPeerPolicy.make(teamIdentifier: "ABCDE12345", peerSigningIdentifier: peer)
        #expect(policy == .sameTeam(signingIdentifier: peer))
    }

    @Test func missingTeamIdentifierFallsBackToSigningIdentifier() {
        let policy = XPCPeerPolicy.make(teamIdentifier: nil, peerSigningIdentifier: peer)
        #expect(policy == .signingIdentifier(peer))
    }

    @Test func emptyTeamIdentifierIsTreatedAsMissing() {
        let policy = XPCPeerPolicy.make(teamIdentifier: "", peerSigningIdentifier: peer)
        #expect(policy == .signingIdentifier(peer))
    }

    @Test func failedTeamLookupFailsClosedToSameTeam() {
        let policy = XPCPeerPolicy.make(teamLookup: .failed, peerSigningIdentifier: peer)
        #expect(policy == .sameTeam(signingIdentifier: peer))
    }

    @Test func lookupWithoutTeamFallsBackToSigningIdentifier() {
        let policy = XPCPeerPolicy.make(teamLookup: .none, peerSigningIdentifier: peer)
        #expect(policy == .signingIdentifier(peer))
    }

    @Test func lookupWithTeamKeepsSameTeam() {
        let policy = XPCPeerPolicy.make(teamLookup: .team("ABCDE12345"), peerSigningIdentifier: peer)
        #expect(policy == .sameTeam(signingIdentifier: peer))
    }

    @Test func emptyTeamInLookupIsTreatedAsNone() {
        let policy = XPCPeerPolicy.make(teamLookup: .team(""), peerSigningIdentifier: peer)
        #expect(policy == .signingIdentifier(peer))
    }

    @Test func requirementIsNeverDropped() {
        for team in [nil, "", "ABCDE12345"] as [String?] {
            let policy = XPCPeerPolicy.make(teamIdentifier: team, peerSigningIdentifier: peer)
            switch policy {
            case .sameTeam(let id), .signingIdentifier(let id):
                #expect(id == peer)
            }
        }
    }
}
