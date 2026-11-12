//
//  DMGBackgroundTests.swift
//  TrincanoTests
//

import Foundation
import ImageIO
import Testing

/// The disk image background (arrow "drag to Applications") ships as @1x and @2x.
struct DMGBackgroundTests {
    private let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/dmg")

    private func size(of name: String) -> (Int, Int)? {
        guard
            let source = CGImageSourceCreateWithURL(folder.appendingPathComponent(name) as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return (width, height)
    }

    @Test func oneXMatchesTheWindow() throws {
        let one = try #require(size(of: "background.png"))
        #expect(one == (660, 460))
    }

    @Test func twoXIsExactlyDouble() throws {
        let two = try #require(size(of: "background@2x.png"))
        #expect(two == (1320, 920))
    }
}
