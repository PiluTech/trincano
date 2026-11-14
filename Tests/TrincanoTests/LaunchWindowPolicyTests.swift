//
//  LaunchWindowPolicyTests.swift
//  TrincanoTests
//

import Testing

struct LaunchWindowPolicyTests {
    @Test func firstLaunchWithMissingPermissionsOpensTheWindow() {
        #expect(LaunchWindowPolicy.permissionsPromptAtLaunch(permissionsMissing: true, promptedBefore: false) == .openWindow)
    }

    @Test func laterLaunchesWithMissingPermissionsOnlyShowTheIndicator() {
        // Reinstalling with another signature or resetting TCC must not pop the window on every boot.
        #expect(LaunchWindowPolicy.permissionsPromptAtLaunch(permissionsMissing: true, promptedBefore: true) == .showIndicator)
    }

    @Test func nothingHappensWhenPermissionsAreGranted() {
        #expect(LaunchWindowPolicy.permissionsPromptAtLaunch(permissionsMissing: false, promptedBefore: false) == .none)
        #expect(LaunchWindowPolicy.permissionsPromptAtLaunch(permissionsMissing: false, promptedBefore: true) == .none)
    }

    @Test func setupFinishesWhenPermissionsAreGrantedWhileTheIndicatorIsShown() {
        #expect(LaunchWindowPolicy.shouldFinishSetup(indicatorShown: true, permissionsMissing: false))
        #expect(!LaunchWindowPolicy.shouldFinishSetup(indicatorShown: true, permissionsMissing: true))
        #expect(!LaunchWindowPolicy.shouldFinishSetup(indicatorShown: false, permissionsMissing: false))
    }
}
