//
//  IceBarPresentationPolicyTests.swift
//  TrincanoTests
//

import Testing

struct IceBarPresentationPolicyTests {
    @Test func showsImmediatelyWhenEveryItemHasAnImage() {
        #expect(IceBarPresentationPolicy.shouldWaitForRefresh(itemCount: 5, itemsWithImages: 5) == false)
    }

    @Test func showsImmediatelyWhenAtLeastSomeItemsHaveImages() {
        // The rest is filled in by the background refresh; waiting up to 1 s
        // for a few items is what made the bar feel slow.
        #expect(IceBarPresentationPolicy.shouldWaitForRefresh(itemCount: 5, itemsWithImages: 2) == false)
    }

    @Test func waitsWhenThereAreItemsButNoImagesYet() {
        #expect(IceBarPresentationPolicy.shouldWaitForRefresh(itemCount: 3, itemsWithImages: 0))
    }

    @Test func doesNotWaitForAnEmptySection() {
        #expect(IceBarPresentationPolicy.shouldWaitForRefresh(itemCount: 0, itemsWithImages: 0) == false)
    }

    @Test func periodicTickDoesNotCaptureWhileTheBarIsClosed() {
        // A closed bar must not capture the screen every 5 s.
        var captures = 0
        IceBarPeriodicRefresh.run(isBarVisible: false) { captures += 1 }
        #expect(captures == 0)
    }

    @Test func periodicTickCapturesOnceWhileTheBarIsVisible() {
        var captures = 0
        IceBarPeriodicRefresh.run(isBarVisible: true) { captures += 1 }
        #expect(captures == 1)
    }
}
