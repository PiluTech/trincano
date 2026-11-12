//
//  MoveToApplicationsPlanTests.swift
//  TrincanoTests
//

import Testing

struct MoveToApplicationsPlanTests {
    private let home = "/Users/tester"

    private func decide(_ path: String, declined: Bool = false) -> MoveToApplicationsPlan.Decision {
        MoveToApplicationsPlan.decide(bundlePath: path, homeDirectory: home, userDeclined: declined)
    }

    @Test func staysWhenInApplications() {
        #expect(decide("/Applications/Trincano.app") == .stay)
        #expect(decide("/Applications/Utilitarios/Trincano.app") == .stay)
    }

    @Test func staysWhenInUserApplications() {
        #expect(decide("/Users/tester/Applications/Trincano.app") == .stay)
    }

    @Test func offersFromDownloadsAndDeletesOldCopy() {
        #expect(decide("/Users/tester/Downloads/Trincano.app") == .offer(deleteOldCopy: true))
    }

    @Test func offersFromDiskImageWithoutDeleting() {
        #expect(decide("/Volumes/Trincano/Trincano.app") == .offer(deleteOldCopy: false))
    }

    @Test func offersWhenTranslocatedWithoutDeleting() {
        let path = "/private/var/folders/ab/xyz/T/AppTranslocation/1234-ABCD/d/Trincano.app"
        #expect(decide(path) == .offer(deleteOldCopy: false))
    }

    @Test func translocatedPathNeverCountsAsInstalled() {
        // A translocated copy of an app that lives in Applications is still a mirror.
        let path = "/private/var/folders/AppTranslocation/1/d/Applications/Trincano.app"
        #expect(MoveToApplicationsPlan.isInstalled(path, homeDirectory: home) == false)
    }

    @Test func rememberedChoiceStops() {
        #expect(decide("/Users/tester/Downloads/Trincano.app", declined: true) == .stay)
    }

    @Test func developmentBuildsStay() {
        #expect(decide("/Users/tester/Library/Developer/Xcode/DerivedData/Ice-abc/Build/Products/Debug/Trincano.app") == .stay)
        #expect(decide("/Users/tester/code/Trincano/build/Build/Products/Release/Trincano.app") == .stay)
    }

    @Test func lookalikePrefixIsNotInstalled() {
        #expect(decide("/ApplicationsEvil/Trincano.app") == .offer(deleteOldCopy: true))
        #expect(decide("/Users/tester/ApplicationsOld/Trincano.app") == .offer(deleteOldCopy: true))
    }
}
