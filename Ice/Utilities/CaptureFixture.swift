//
//  CaptureFixture.swift
//  Ice
//

// Modo de captura para os prints do catálogo. Só existe no build Debug: o
// Release não compila nada deste arquivo. Ele roda o app com itens fictícios
// (nada do usuário), sem nenhuma varredura da barra real, e salva PNGs só das
// janelas do Trincano. Como gerar: scripts/capture-prints.sh (docs/prints/).
#if DEBUG
import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum CaptureFixture {
    /// A variável de ambiente com a pasta de saída. Presente = modo de captura.
    nonisolated static let directoryKey = "TRINCANO_CAPTURE_DIR"

    /// A pasta de saída dos prints, se o modo de captura está ligado.
    nonisolated static let directory: URL? = {
        guard let path = ProcessInfo.processInfo.environment[directoryKey], !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }()

    /// Um valor que indica se o app roda no modo de captura.
    nonisolated static var isActive: Bool { directory != nil }

    // MARK: Fixture

    /// O tamanho (em pontos) de um item fictício na barra.
    private static let itemSize = CGSize(width: 30, height: 24)

    /// O cache de itens fictícios para a tela dada.
    private static func makeItemCache(displayID: CGDirectDisplayID) -> MenuBarItemManager.ItemCache {
        var cache = MenuBarItemManager.ItemCache(displayID: displayID)
        for section in CaptureFixtureEntry.Section.allCases {
            let name: MenuBarSection.Name = switch section {
            case .visible: .visible
            case .hidden: .hidden
            case .alwaysHidden: .alwaysHidden
            }
            cache[name] = CaptureFixtureCatalog.entries(in: section).map { entry in
                makeItem(for: entry)
            }
        }
        return cache
    }

    private static func makeItem(for entry: CaptureFixtureEntry) -> MenuBarItem {
        let index = CaptureFixtureCatalog.entries.firstIndex(of: entry) ?? 0
        return MenuBarItem(
            captureFixtureTag: MenuBarItemTag(namespace: .string("fixture.trincano"), title: entry.title),
            windowID: CaptureFixtureCatalog.windowID(forEntryAt: index),
            ownerPID: ProcessInfo.processInfo.processIdentifier,
            bounds: CGRect(origin: .zero, size: itemSize),
            title: entry.title
        )
    }

    /// As imagens dos itens fictícios: glifos genéricos de símbolos do sistema.
    private static func makeImages(scale: CGFloat) -> [MenuBarItemTag: MenuBarItemImageCache.CapturedImage] {
        var images = [MenuBarItemTag: MenuBarItemImageCache.CapturedImage]()
        for entry in CaptureFixtureCatalog.entries {
            let tag = makeItem(for: entry).tag
            if let image = renderGlyph(symbol: entry.symbol, scale: scale) {
                images[tag] = image
            }
        }
        return images
    }

    /// Desenha o símbolo, centralizado, num bitmap do tamanho de um item.
    private static func renderGlyph(symbol: String, scale: CGFloat) -> MenuBarItemImageCache.CapturedImage? {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let tint: NSColor = isDark ? .white : .black
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        guard
            let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
        else {
            return nil
        }
        let pixelWidth = Int(itemSize.width * scale)
        let pixelHeight = Int(itemSize.height * scale)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else {
            return nil
        }
        rep.size = itemSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let scaleFactor = min(
            (itemSize.width - 6) / base.size.width,
            (itemSize.height - 6) / base.size.height,
            1
        )
        let glyphSize = CGSize(width: base.size.width * scaleFactor, height: base.size.height * scaleFactor)
        let glyphRect = CGRect(
            x: (itemSize.width - glyphSize.width) / 2,
            y: (itemSize.height - glyphSize.height) / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        base.draw(in: glyphRect)
        tint.setFill()
        glyphRect.fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else {
            return nil
        }
        return MenuBarItemImageCache.CapturedImage(cgImage: cgImage, scale: scale)
    }

    // MARK: Run

    /// Liga o modo de captura: instala a fixture, abre as cenas e salva os PNGs.
    /// Nunca chama `AppState.performSetup`: não há control items, event taps
    /// nem varredura da barra real.
    static func start(appState: AppState) {
        guard let directory else {
            return
        }
        Task { @MainActor in
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try await run(appState: appState, directory: directory)
            } catch {
                FileHandle.standardError.write(Data("capture failed: \(error)\n".utf8))
            }
            NSApp.terminate(nil)
        }
    }

    private static func run(appState: AppState, directory: URL) async throws {
        let screen = NSScreen.screens.first { $0.notchGeometry != nil } ?? NSScreen.main ?? NSScreen.screens[0]

        ScreenCapture.overrideCachedPermissionsForCapture()
        appState.itemManager.installCaptureFixture(makeItemCache(displayID: screen.displayID))
        appState.imageCache.installCaptureFixture(makeImages(scale: screen.backingScaleFactor))
        appState.menuBarManager.iceBarPanel.performSetup(with: appState)

        appState.activate(withPolicy: .regular)
        let backdrop = makeBackdrop(on: screen)

        // Ajustes: Barra organizada (Layout) e Geral.
        appState.navigationState.settingsNavigationIdentifier = .menuBarLayout
        appState.openWindow(.settings)
        let settings = try await waitForWindow(identifier: IceWindowIdentifier.settings.rawValue)
        place(settings, above: backdrop)
        try await snap(settings, named: "01-barra-organizada", into: directory)

        appState.navigationState.settingsNavigationIdentifier = .general
        try await pause(0.8)
        try await snap(settings, named: "02-ajustes-gerais", into: directory)
        settings.close()

        // A Barra do Trincano: extensão do notch (seção Ocultos) e barra comum.
        let panel = appState.menuBarManager.iceBarPanel
        await panel.show(section: .hidden, on: screen)
        try await pause(1.0)
        try await snap(panel, named: "03-barra-no-notch", into: directory, includesShadow: false)
        panel.close()

        await panel.show(section: .alwaysHidden, on: screen)
        try await pause(1.0)
        try await snap(panel, named: "04-barra-do-trincano", into: directory, includesShadow: false)
        panel.close()

        // O menu do ícone do Trincano.
        try await snapMenu(appState: appState, backdrop: backdrop, into: directory)
        backdrop.close()
    }

    // MARK: Windows

    /// Uma janela de fundo neutra (gradiente), para o vidro das janelas do
    /// Trincano não refletir o que o usuário tem aberto atrás delas.
    private static func makeBackdrop(on screen: NSScreen) -> NSWindow {
        let window = BackdropWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.contentView = NSHostingView(
            rootView: LinearGradient(
                colors: [Color(red: 0.22, green: 0.29, blue: 0.46), Color(red: 0.55, green: 0.40, blue: 0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        return window
    }

    /// Uma janela sem borda que pode ser a janela principal (o menu só abre
    /// a partir de uma janela que aceita o foco).
    private final class BackdropWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }

    private static func place(_ window: NSWindow, above backdrop: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        backdrop.order(.below, relativeTo: window.windowNumber)
    }

    private static func waitForWindow(identifier: String) async throws -> NSWindow {
        for _ in 0..<100 {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == identifier }) {
                return window
            }
            try await pause(0.1)
        }
        throw CaptureError.windowNotFound(identifier)
    }

    private static func pause(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    // MARK: Menu

    private static func snapMenu(appState: AppState, backdrop: NSWindow, into directory: URL) async throws {
        guard let section = appState.menuBarManager.section(withName: .visible) else {
            throw CaptureError.windowNotFound("menu")
        }
        let menu = section.controlItem.makeMenuForCapture(with: appState)
        backdrop.makeKeyAndOrderFront(nil)
        guard let contentView = backdrop.contentView else {
            throw CaptureError.windowNotFound("backdrop")
        }
        let y: CGFloat = contentView.isFlipped ? 160 : contentView.bounds.maxY - 160
        let location = NSPoint(x: contentView.bounds.midX - 120, y: y)
        // Invariante: o menu só é tocado na main thread (o Timer abaixo roda na main run loop).
        nonisolated(unsafe) let menuRef = menu

        // O menu bloqueia a run loop em modo de tracking, onde as tarefas do
        // Swift Concurrency não rodam: a captura e o fechamento saem de um
        // Timer síncrono, registrado nos modos comum e de tracking.
        let rawURL = directory.appendingPathComponent("05-menu-do-trincano.raw.png")
        let finalURL = directory.appendingPathComponent("05-menu-do-trincano.png")
        let timer = Timer(timeInterval: 0.8, repeats: false) { _ in
            // Invariante: o Timer é agendado na main run loop, então roda na main thread.
            MainActor.assumeIsolated {
                defer { menuRef.cancelTracking() }
                guard let rect = menuWindowBounds() else {
                    FileHandle.standardError.write(Data("capture: menu window not found\n".utf8))
                    return
                }
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    // -R: o -l não isola a janela de um menu em tracking.
                    process.arguments = ["-x", "-R", "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))", rawURL.path]
                    try process.run()
                    process.waitUntilExit()
                    try stripMetadata(from: rawURL, to: finalURL)
                    try? FileManager.default.removeItem(at: rawURL)
                } catch {
                    FileHandle.standardError.write(Data("capture: menu snap failed: \(error)\n".utf8))
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        menu.popUp(positioning: nil, at: location, in: contentView)
    }

    /// Os limites (em pontos, coordenadas de tela) do menu aberto, entre as
    /// janelas do próprio app.
    private static func menuWindowBounds() -> CGRect? {
        let pid = ProcessInfo.processInfo.processIdentifier
        let popUpLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        // O tracking cria uma janela de captura de eventos do tamanho da tela
        // no mesmo nível; o menu é a menor das janelas desse nível.
        func area(_ info: [String: Any]) -> CGFloat {
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                return .greatestFiniteMagnitude
            }
            return (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
        }
        let candidates = list
            .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
            .filter { ($0[kCGWindowLayer as String] as? Int ?? 0) >= popUpLevel }
        let smallest = candidates.min { area($0) < area($1) }
        guard
            let bounds = smallest?[kCGWindowBounds as String] as? [String: CGFloat],
            let x = bounds["X"], let y = bounds["Y"], let width = bounds["Width"], let height = bounds["Height"]
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: Snapshot

    private enum CaptureError: Error {
        case windowNotFound(String)
        case screencaptureFailed(Int32)
    }

    private static func snap(
        _ window: NSWindow,
        named name: String,
        into directory: URL,
        includesShadow: Bool = true
    ) async throws {
        try await snap(
            windowID: CGWindowID(window.windowNumber),
            named: name,
            into: directory,
            includesShadow: includesShadow
        )
    }

    /// Captura só a janela dada (sem a barra de menus real nem o resto da tela)
    /// e grava o PNG sem metadados.
    private static func snap(
        windowID: CGWindowID,
        named name: String,
        into directory: URL,
        includesShadow: Bool = true
    ) async throws {
        try await pause(0.5)
        let raw = directory.appendingPathComponent("\(name).raw.png")
        let final = directory.appendingPathComponent("\(name).png")
        var arguments = ["-x", "-l", String(windowID)]
        if !includesShadow {
            arguments.append("-o")
        }
        arguments.append(raw.path)
        let status = try await runScreencapture(arguments)
        guard status == 0 else {
            throw CaptureError.screencaptureFailed(status)
        }
        try stripMetadata(from: raw, to: final)
        try? FileManager.default.removeItem(at: raw)
    }

    private static func runScreencapture(_ arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Regrava o PNG só com os pixels: sem EXIF, XMP nem texto de captura.
    private static func stripMetadata(from source: URL, to destination: URL) throws {
        guard
            let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
            let target = CGImageDestinationCreateWithURL(
                destination as CFURL, UTType.png.identifier as CFString, 1, nil
            )
        else {
            throw CaptureError.screencaptureFailed(-1)
        }
        CGImageDestinationAddImage(target, image, nil)
        guard CGImageDestinationFinalize(target) else {
            throw CaptureError.screencaptureFailed(-2)
        }
    }
}
#endif
