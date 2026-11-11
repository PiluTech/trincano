//
//  CaptureFixtureCatalogTests.swift
//  TrincanoTests
//

#if DEBUG
import Foundation
import Testing

@Suite("CaptureFixtureCatalog")
struct CaptureFixtureCatalogTests {
    @Test("todas as seções têm itens, para a barra organizada não sair vazia")
    func everySectionHasEntries() {
        for section in CaptureFixtureEntry.Section.allCases {
            #expect(!CaptureFixtureCatalog.entries(in: section).isEmpty)
        }
    }

    @Test("títulos e símbolos são únicos")
    func titlesAndSymbolsAreUnique() {
        let titles = CaptureFixtureCatalog.entries.map(\.title)
        let symbols = CaptureFixtureCatalog.entries.map(\.symbol)
        #expect(Set(titles).count == titles.count)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test("nada pessoal: nem o nome do usuário do Mac nem e-mail")
    func containsNothingPersonal() {
        let personal = [NSFullUserName(), NSUserName()].filter { !$0.isEmpty }.map { $0.lowercased() }
        for entry in CaptureFixtureCatalog.entries {
            let text = (entry.title + " " + entry.symbol).lowercased()
            #expect(!text.contains("@"))
            for name in personal {
                #expect(!text.contains(name))
            }
        }
    }

    @Test("os identificadores de janela são únicos e ficam na faixa reservada")
    func windowIDsAreUniqueAndReserved() {
        let ids = CaptureFixtureCatalog.entries.indices.map { CaptureFixtureCatalog.windowID(forEntryAt: $0) }
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0 >= 900_000 })
    }
}
#endif
