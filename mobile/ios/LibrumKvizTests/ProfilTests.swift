import SwiftUI
import XCTest
@testable import LibrumKviz

/// Odgovor RPC profil_igraca (stvaran oblik iz baze, podaci igrača zamenjeni probnim).
@MainActor
final class ProfilTests: XCTestCase {
    static let odgovor = #"""
    {"id": "00000000-0000-0000-0000-000000000001", "od": "2026-10-18T12:26:39.819198+00:00", "bio": "Volim istoriju i slikare. Izazovi me na duel!",
     "ime": "Probni Igrač", "grad": "Beograd", "nadimak": "probni", "avatar": "animal_25.png",
     "veb": {"pro": {"niz": 87, "rekord": 7335, "partija": 23, "max_pitanja": 643}, "book": {"zanr": "Razno", "rekord": 20, "partija": 1, "max_pitanja": 17},
             "brzi": {"rekord": 210, "tacnih": 3680, "partija": 305, "tacnost": 64}, "duel": {"pobeda": 0, "poraza": 0, "nereseno": 0},
             "vesanje": {"bodovi": 664, "pobeda": 10, "partija": 18}},
     "igre": [], "prati": 8, "pratilaca": 12, "ja_pratim": false, "autor_pitanja": 3, "pomoci": {}, "partija": 347,
     "skoro": [{"kad": "2026-10-28T13:58:21.95054+00:00", "igra": "brzi", "poeni": 210}, {"kad": "2026-10-28T13:57:18.952441+00:00", "igra": "pro", "poeni": 135}],
     "pitanja": {"tacnost": 70, "odgovora": 8544, "prosek_ms": 2944, "ponovljenih": 7533, "jedinstvenih": 1011}}
    """#

    func testOdgovorSeCitaICrta() throws {
        let p = try JSONDecoder().decode(ProfilIgracaView.Profil.self, from: Data(Self.odgovor.utf8))
        XCTAssertEqual(p.pitanja?.jedinstvenih, 1011)
        XCTAssertEqual(p.pitanja?.ponovljenih, 7533)
        XCTAssertEqual(p.veb?.pro?.rekord, 7335)
        XCTAssertEqual(p.pratilaca, 12)
        // Profil iscrtan u sliku, da se izgled proveri i bez servera (Supabase blokiran 02.11).
        let prikaz = VStack(spacing: 18) {
                ProfilZaglavlje(profil: p, nivo: 4) { Button("Uredi profil") {}.buttonStyle(.sekundarno) }
                ProfilStatistike(profil: p)
            }
            .padding(16).frame(width: 402).background(Color(hex: 0xF3F0E6))
        .environment(Sesija()).environment(Napredak())
        let r = ImageRenderer(content: prikaz)
        r.scale = 2
        r.proposedSize = .init(width: 402, height: nil)
        let slika = try XCTUnwrap(r.uiImage)
        if let putanja = ProcessInfo.processInfo.environment["PROFIL_SLIKA"] { try slika.pngData()?.write(to: URL(fileURLWithPath: putanja)) }
        XCTAssertGreaterThan(slika.size.height, 600)
    }
}

/// Izgled kartice Igrači sa primerom objava (crta se u sliku, bez servera).
@MainActor
final class IgraciMokapTests: XCTestCase {
    func testTokObjavaSeCrta() throws {
        func o(_ id: Int, _ ime: String, _ av: String, _ vrsta: String, _ igra: String?, _ tekst: String, _ poeni: Int?, srca: Int, kom: Int, moje: Bool = false) -> Zajednica.Objava {
            Zajednica.Objava(id: id, ko: "u\(id)", nadimak: ime, avatar: av, vrsta: vrsta, igra: igra, tekst: tekst, poeni: poeni, kod_sobe: nil,
                             created_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(-id) * 1700)), srca: srca, moje_srce: moje, komentara: kom, moja: false)
        }
        let objave = [
            o(1, "Milan", "animal_25.png", "poziv_duel", "duel", "Ko sme na duel iz geografije? Pobeđujem sve do Kine.", nil, srca: 4, kom: 3),
            o(2, "Čiča", "animal_47.png", "rezultat", "osvajanje", "Osvojio sam celu Evropu za 6 krugova!", 2140, srca: 12, kom: 5, moje: true),
            o(3, "Dabetić", "animal_10.png", "poziv_tim", "osvajanje", "Tražim saigrača za Osvajanje, timovi po dvoje. Večeras u 21h.", nil, srca: 2, kom: 1),
        ]
        let prikaz = VStack(alignment: .leading, spacing: 14) {
            Naslov(tekst: "Igrači", velicina: 34)
            ForEach(objave) { ob in KarticaObjave(o: ob, komentari: {}, promena: { _ in }, nestala: {}) }
        }
        .padding(16).frame(width: 402).background(Color(hex: 0xF3F0E6))
        .environment(Sesija()).environment(Napredak())
        let r = ImageRenderer(content: prikaz)
        r.scale = 2
        r.proposedSize = .init(width: 402, height: nil)
        let slika = try XCTUnwrap(r.uiImage)
        if let putanja = ProcessInfo.processInfo.environment["IGRACI_SLIKA"] { try slika.pngData()?.write(to: URL(fileURLWithPath: putanja)) }
        XCTAssertGreaterThan(slika.size.height, 600)
    }
}
