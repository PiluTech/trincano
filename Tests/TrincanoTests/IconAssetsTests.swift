//
//  IconAssetsTests.swift
//  TrincanoTests
//

import CryptoKit
import Foundation
import ImageIO
import Testing

/// Checks the app icon and the menu bar glyph assets (Frost Bar identity).
struct IconAssetsTests {
    private var catalog: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Ice/Resources/Assets.xcassets")
    }

    private func pixelSize(of url: URL) -> (width: Int, height: Int, hasAlpha: Bool)? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return (width, height, (props[kCGImagePropertyHasAlpha] as? Bool) ?? false)
    }

    @Test func appIconHasEverySizeWithTheRightPixels() throws {
        let expected: [(String, Int)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024),
        ]
        for (name, side) in expected {
            let url = catalog.appendingPathComponent("AppIcon.appiconset/\(name).png")
            let size = try #require(pixelSize(of: url), "\(name) missing or unreadable")
            #expect(size.width == side && size.height == side, "\(name): \(size)")
            #expect(size.hasAlpha, "\(name) needs transparent margins")
        }
    }

    @Test func menuBarGlyphsAre18PointTemplatesAtEveryScale() throws {
        for name in ["FrostBarFill", "FrostBarStroke"] {
            let dir = catalog.appendingPathComponent("ControlItemImages/FrostBar/\(name).imageset")
            for (suffix, side) in [("", 18), ("@2x", 36), ("@3x", 54)] {
                let url = dir.appendingPathComponent("\(name)\(suffix).png")
                let size = try #require(pixelSize(of: url), "\(name)\(suffix) missing")
                #expect(size.width == side && size.height == side, "\(name)\(suffix): \(size)")
                #expect(size.hasAlpha)
            }
            let json = try Data(contentsOf: dir.appendingPathComponent("Contents.json"))
            let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
            let properties = object["properties"] as? [String: Any]
            #expect(properties?["template-rendering-intent"] as? String == "template", "\(name) must be a template")
        }
    }

    /// `hasAlpha` only says the PNG has an alpha channel; a glyph rendered on a white backdrop still has one.
    /// A template glyph must be transparent around the art, or it shows up as a white square.
    private func cornerAlphas(of url: URL) -> (corners: [UInt8], maxAlpha: UInt8)? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] }
        let corners = [alpha(0, 0), alpha(width - 1, 0), alpha(0, height - 1), alpha(width - 1, height - 1)]
        let maxAlpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }.max() ?? 0
        return (corners, maxAlpha)
    }

    @Test func menuBarGlyphsAreTransparentOutsideTheArtAtEveryScale() throws {
        for name in ["FrostBarFill", "FrostBarStroke"] {
            let dir = catalog.appendingPathComponent("ControlItemImages/FrostBar/\(name).imageset")
            for suffix in ["", "@2x", "@3x"] {
                let url = dir.appendingPathComponent("\(name)\(suffix).png")
                let alphas = try #require(cornerAlphas(of: url), "\(name)\(suffix) unreadable")
                #expect(alphas.corners.allSatisfy { $0 == 0 }, "\(name)\(suffix) is opaque in the corners (white square): \(alphas.corners)")
                #expect(alphas.maxAlpha > 200, "\(name)\(suffix) has no art (blank glyph)")
            }
        }
    }

    // MARK: Provenance: the referenced PNGs must be the Frost Bar art, not the Ice cube.

    private var appIconDir: URL {
        catalog.appendingPathComponent("AppIcon.appiconset")
    }

    private func averageColor(of url: URL) -> (r: Double, g: Double, b: Double, luminance: Double)? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var sums = (r: 0.0, g: 0.0, b: 0.0)
        var count = 0.0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.95 else { continue }          // opaque pixels only (skip the transparent margin)
            sums.r += Double(pixels[offset]) / 255
            sums.g += Double(pixels[offset + 1]) / 255
            sums.b += Double(pixels[offset + 2]) / 255
            count += 1
        }
        guard count > 0 else { return nil }
        let (r, g, b) = (sums.r / count, sums.g / count, sums.b / count)
        return (r, g, b, 0.2126 * r + 0.7152 * g + 0.0722 * b)
    }

    @Test func appIconIsTheLightMintBarNotTheDarkBlueIceCube() throws {
        for name in ["icon_512x512", "icon_512x512@2x", "icon_128x128"] {
            let color = try #require(averageColor(of: appIconDir.appendingPathComponent("\(name).png")), "\(name)")
            #expect(color.luminance > 0.6, "\(name) is too dark (the Ice cube is dark navy): \(color)")
            #expect(color.g >= color.r, "\(name) should lean mint/teal, not blue: \(color)")
            #expect(color.b < 0.99 && !(color.b > color.g + 0.15), "\(name) is blue-dominant: \(color)")
        }
    }

    @Test func everyFileReferencedByContentsJSONExistsAndNothingIsOrphaned() throws {
        let json = try Data(contentsOf: appIconDir.appendingPathComponent("Contents.json"))
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let images = try #require(object["images"] as? [[String: Any]])
        let referenced = Set(images.compactMap { $0["filename"] as? String })
        #expect(referenced.count == 10)
        let onDisk = Set(try FileManager.default.contentsOfDirectory(atPath: appIconDir.path))
        #expect(referenced.isSubset(of: onDisk), "missing: \(referenced.subtracting(onDisk))")
        #expect(onDisk.subtracting(referenced).subtracting(["Contents.json"]).isEmpty,
                "orphan files: \(onDisk.subtracting(referenced).subtracting(["Contents.json"]))")
    }

    @Test func referencedPNGsMatchTheHashesRecordedByTheGenerationScript() throws {
        let sums = catalog.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/identidade/icone/SHA256SUMS")
        let lines = try String(contentsOf: sums, encoding: .utf8).split(separator: "\n")
        #expect(lines.count >= 10)
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            let hash = String(parts[0]), file = String(parts[1])
            let data = try Data(contentsOf: appIconDir.appendingPathComponent(file))
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            #expect(actual == hash, "\(file) does not match the generated art")
        }
    }

    /// Names of every chunk in a PNG file, in order.
    private func chunkNames(of url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(Array(data.prefix(8)) == signature, "\(url.lastPathComponent) is not a PNG")
        var names: [String] = []
        var offset = 8
        while offset + 8 <= data.count {
            let length = data[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
            names.append(String(decoding: data[offset + 4..<offset + 8], as: UTF8.self))
            offset += 12 + length
        }
        return names
    }

    @Test func iconAssetsCarryNoMetadataChunks() throws {
        let forbidden: Set<String> = ["eXIf", "tEXt", "iTXt", "zTXt"]
        let glyphs = catalog.appendingPathComponent("ControlItemImages/FrostBar")
        var files = try FileManager.default.contentsOfDirectory(at: appIconDir, includingPropertiesForKeys: nil)
        let enumerator = FileManager.default.enumerator(at: glyphs, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            files.append(url)
        }
        let pngs = files.filter { $0.pathExtension == "png" }
        #expect(pngs.count >= 10)
        for url in pngs {
            let found = Set(try chunkNames(of: url)).intersection(forbidden)
            #expect(found.isEmpty, "\(url.lastPathComponent) has metadata chunks: \(found.sorted())")
        }
    }
}
