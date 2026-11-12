// Gera o fundo da janela do .dmg (@1x e @2x): seta "arraste para Aplicativos".
// Uso: swift scripts/make-dmg-background.swift <pasta-de-saída>
//
// O Finder desenha o rótulo dos ícones na cor do tema (claro ou escuro) por cima do fundo, então o
// fundo é um cinza-azulado de luminância média: texto branco e preto passam de ~4,5:1 nos dois.
// Os números abaixo (janela, posições) são os mesmos que scripts/release.sh usa no AppleScript.
import AppKit

let windowSize = CGSize(width: 660, height: 460)
let appCenter = CGPoint(x: 170, y: 190)           // coordenadas a partir do topo esquerdo
let applicationsCenter = CGPoint(x: 490, y: 190)
let base = (r: 104.0, g: 120.0, b: 142.0)

func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
    func lin(_ c: Double) -> Double { let v = c / 255; return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}
let lum = luminance(base.r, base.g, base.b)
let whiteContrast = 1.05 / (lum + 0.05), blackContrast = (lum + 0.05) / 0.05
precondition(whiteContrast >= 4.4 && blackContrast >= 4.4, "fundo sem contraste nos dois temas")

func render(scale: Int) -> Data {
    let w = Int(windowSize.width) * scale, h = Int(windowSize.height) * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = windowSize  // 72 dpi no @1x e 144 dpi no @2x
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    // O contexto do bitmap já mapeia pontos para pixels (rep.size): não escalar de novo.
    // origem no topo esquerdo
    cg.translateBy(x: 0, y: windowSize.height)
    cg.scaleBy(x: 1, y: -1)

    NSColor(deviceRed: base.r / 255, green: base.g / 255, blue: base.b / 255, alpha: 1).setFill()
    CGRect(origin: .zero, size: windowSize).fill()

    // Seta branca entre os dois ícones.
    let y = appCenter.y, x0 = appCenter.x + 100, x1 = applicationsCenter.x - 100
    cg.setStrokeColor(NSColor.white.cgColor)
    cg.setLineWidth(6); cg.setLineCap(.round); cg.setLineJoin(.round)
    cg.move(to: CGPoint(x: x0, y: y)); cg.addLine(to: CGPoint(x: x1, y: y)); cg.strokePath()
    cg.move(to: CGPoint(x: x1 - 26, y: y - 24)); cg.addLine(to: CGPoint(x: x1, y: y)); cg.addLine(to: CGPoint(x: x1 - 26, y: y + 24))
    cg.strokePath()

    // Textos (o contexto está espelhado: desenhar com a matriz do texto desfeita).
    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, at center: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor.white]
        let str = NSAttributedString(string: s, attributes: attrs)
        let sz = str.size()
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y); cg.scaleBy(x: 1, y: -1)
        str.draw(at: CGPoint(x: -sz.width / 2, y: -sz.height / 2))
        cg.restoreGState()
    }
    text("Arraste o Trincano para Aplicativos", size: 20, weight: .semibold, at: CGPoint(x: 330, y: 92))
    text("Drag Trincano to Applications", size: 13, weight: .regular, at: CGPoint(x: 330, y: 120))

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else { fatalError("uso: make-dmg-background.swift <pasta>") }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
try render(scale: 1).write(to: out.appendingPathComponent("background.png"))
try render(scale: 2).write(to: out.appendingPathComponent("background@2x.png"))
print(String(format: "ok (contraste branco %.2f, preto %.2f)", whiteContrast, blackContrast))
