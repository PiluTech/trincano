#!/usr/bin/env swift
// Renderiza um SVG em PNG com fundo transparente (glifo de template da barra de menus).
// Uso: render-glyph.swift entrada.svg lado-em-pixels saida.png
// (o qlmanage não serve: renderiza SVG pequeno sobre fundo branco e perde o desenho.)
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 4, let side = Int(args[2]), side > 0, let svg = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("uso: render-glyph.swift entrada.svg lado saida.png\n".utf8))
    exit(1)
}
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
svg.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[3]))
