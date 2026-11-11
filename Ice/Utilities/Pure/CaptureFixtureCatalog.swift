//
//  CaptureFixtureCatalog.swift
//  Ice
//

// Catálogo da fixture dos prints (só Debug): itens fictícios da barra de
// menus, sem nenhum app real do usuário. Lógica pura (sem AppKit), compilada
// também no alvo de testes.
#if DEBUG
import Foundation

/// Um item fictício da barra de menus, usado só nos prints do catálogo.
struct CaptureFixtureEntry: Equatable {
    /// A seção onde o item aparece.
    enum Section: CaseIterable {
        case visible
        case hidden
        case alwaysHidden
    }

    /// O título do item (único em todo o catálogo).
    let title: String

    /// O nome do símbolo SF usado como ícone genérico.
    let symbol: String

    /// A seção do item.
    let section: Section
}

enum CaptureFixtureCatalog {
    /// Os itens fictícios, em ordem de exibição dentro de cada seção.
    static let entries: [CaptureFixtureEntry] = [
        // Visíveis.
        .init(title: "Rede", symbol: "wifi", section: .visible),
        .init(title: "Som", symbol: "speaker.wave.2.fill", section: .visible),
        .init(title: "Bateria", symbol: "battery.75percent", section: .visible),
        .init(title: "Foco", symbol: "moon.fill", section: .visible),
        .init(title: "Agenda", symbol: "calendar", section: .visible),
        // Ocultos.
        .init(title: "Notas", symbol: "note.text", section: .hidden),
        .init(title: "Sincronização", symbol: "arrow.triangle.2.circlepath", section: .hidden),
        .init(title: "Câmera", symbol: "camera.fill", section: .hidden),
        .init(title: "Clima", symbol: "cloud.sun.fill", section: .hidden),
        .init(title: "Lembretes", symbol: "checklist", section: .hidden),
        .init(title: "Temporizador", symbol: "timer", section: .hidden),
        // Sempre ocultos.
        .init(title: "Backup", symbol: "externaldrive.fill", section: .alwaysHidden),
        .init(title: "Bluetooth", symbol: "antenna.radiowaves.left.and.right", section: .alwaysHidden),
        .init(title: "Desempenho", symbol: "gauge.with.dots.needle.50percent", section: .alwaysHidden),
        .init(title: "Compartilhar", symbol: "square.and.arrow.up", section: .alwaysHidden),
    ]

    /// Os itens de uma seção, na ordem de exibição.
    static func entries(in section: CaptureFixtureEntry.Section) -> [CaptureFixtureEntry] {
        entries.filter { $0.section == section }
    }

    /// O identificador da janela fictícia de um item: fica numa faixa alta que
    /// nenhuma janela real usa, então consultas de geometria não acham nada.
    static func windowID(forEntryAt index: Int) -> UInt32 {
        900_000 + UInt32(index)
    }
}
#endif
