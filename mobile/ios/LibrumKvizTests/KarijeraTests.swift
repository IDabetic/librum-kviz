import XCTest
@testable import LibrumKviz

final class KarijeraTests: XCTestCase {
    /// Svaka rečenica šefa ima uparene {muški|ženski} oblike i posle izbora ne ostaje nijedna zagrada.
    func testSefOblikPoPolu() {
        let banke = [Sef.tacno, Sef.netacno, Sef.isteklo, Sef.blagoTacno, Sef.blagoNetacno, Sef.jakoTacno, Sef.jakoNetacno, Sef.smehTacno, Sef.smehNetacno]
        for banka in banke {
            for r in banka {
                XCTAssertEqual(r.filter { $0 == "{" }.count, r.filter { $0 == "}" }.count, r)
                XCTAssertEqual(r.filter { $0 == "[" }.count, r.filter { $0 == "]" }.count, r)
            }
        }
        XCTAssertEqual(Sef.tacno.count, 110)
        XCTAssertEqual(Sef.netacno.count, 120)
        XCTAssertEqual(Sef.isteklo.count, 50)
        XCTAssertEqual(Sef.blagoTacno.count, 40)
        XCTAssertEqual(Sef.blagoNetacno.count, 40)
        XCTAssertEqual(Sef.jakoTacno.count, 40)
        XCTAssertEqual(Sef.jakoNetacno.count, 60)
        XCTAssertEqual(Sef.smehTacno.count + Sef.smehNetacno.count, 40)
        XCTAssertEqual(Sef.ometanja.count, 60)
        for _ in 0..<300 {
            for p in [Sef.Povod.tacno, .netacno, .isteklo] {
                for j in 1...3 {
                    for z in [true, false] {
                        let r = Sef.recenica(p, jacina: j, smeh: true, zensko: z, sefZensko: !z)
                        XCTAssertFalse(r.contains("{") || r.contains("}") || r.contains("[") || r.contains("]") || r.contains("|"), r)
                    }
                }
            }
        }
    }

    /// Šefica govori o sebi u ženskom rodu, igrač ostaje u svom.
    /// Komentar šefa staje u dva reda (vlasnik 05.11): svaka rečenica ≤ 52 znaka u svakom obliku.
    func testDvaReda() {
        let sve = [Sef.tacno, Sef.netacno, Sef.isteklo, Sef.blagoTacno, Sef.blagoNetacno, Sef.jakoTacno, Sef.jakoNetacno, Sef.smehTacno, Sef.smehNetacno].flatMap { $0 }
        for t in sve { for z in [true, false] { for sz in [true, false] {
            let r = Sef.oblik(t, zensko: z, sefZensko: sz)
            XCTAssertLessThanOrEqual(r.count, 52, r)
        } } }
    }

    func testRodSefa() {
        XCTAssertEqual(Sef.oblik("{Bio|Bila} si brz. [Ponosan|Ponosna] sam.", zensko: false, sefZensko: true), "Bio si brz. Ponosna sam.")
        XCTAssertEqual(Sef.oblik("[Znao|Znala] sam.", zensko: true), "Znao sam.")
        XCTAssertEqual(Sef.likovi.filter(\.zensko).count, 3)
        for o in Sef.ometanja { XCTAssertFalse(Sef.oblik(o.tekst, zensko: true).contains("{"), o.tekst) }
    }

    /// Nisko 1, srednje 2–3, visoko 4–5 ometanja po rundi, nikad dva pitanja zaredom; haos samo na visokom.
    func testRasporedOmetanja() {
        for _ in 0..<500 {
            for (nivo, opseg) in [(0, 0...0), (1, 1...1), (2, 2...3), (3, 4...5)] {
                let r = Sef.rasporedOmetanja(nivo: nivo)
                XCTAssertTrue(r.allSatisfy { (0..<10).contains($0) && !r.contains($0 + 1) })
                XCTAssertTrue(opseg.contains(r.count) || (nivo == 3 && r.count >= 3), "\(nivo): \(r)")
            }
            XCTAssertEqual(Sef.ometanje(nivo: 1, veliko: true).vrsta, .upad)
            XCTAssertNotEqual(Sef.ometanje(nivo: 2, veliko: true).vrsta, .haos)
        }
        // Veliko ometanje (zadatak/haos) najviše jednom po rundi: „često” uvek jedno, „ponekad” oko pola rundi, „retko” nikad.
        let r: Set<Int> = [1, 4, 7]
        XCTAssertTrue((0..<300).allSatisfy { _ in Sef.velikoPitanje(nivo: 3, raspored: r).map(r.contains) == true })
        XCTAssertTrue((0..<300).allSatisfy { _ in Sef.velikoPitanje(nivo: 1, raspored: r) == nil })
        let ponekad = (0..<2000).filter { _ in Sef.velikoPitanje(nivo: 2, raspored: r) != nil }.count
        XCTAssertTrue((800...1200).contains(ponekad), "\(ponekad)")
        XCTAssertTrue((0..<300).allSatisfy { _ in Sef.ometanje(nivo: 3, veliko: false).vrsta == .upad })
        XCTAssertTrue((0..<300).allSatisfy { _ in Sef.ometanje(nivo: 2, veliko: true).vrsta == .zadatak })
        XCTAssertEqual(Sef.Nivo(tacno: 3, netacno: 3, ometanja: 3).mirno(true), Sef.Nivo(tacno: 1, netacno: 1, ometanja: 0, smeh: false))
    }

    /// Igrač vidi naše poruke iz funkcija, a tehničke greške baze ne (05.11: „column reference vlasnik is ambiguous”).
    func testPorukeServera() {
        let tehnicka = Supabase.greska(Data(#"{"code":"42702","message":"column reference \"vlasnik\" is ambiguous"}"#.utf8), kod: 400)
        XCTAssertFalse(tehnicka.localizedDescription.contains("ambiguous"))
        let nasa = Supabase.greska(Data(#"{"code":"22023","message":"Najviše 3 slobodna dana u nedelji"}"#.utf8), kod: 400)
        XCTAssertEqual(nasa.localizedDescription, "Najviše 3 slobodna dana u nedelji")
    }

    /// Mešavina u aplikaciji je ista kao na serveru (karijera_runda_pitanja): uvek 10 pitanja.
    func testMesavinaKaoServer() {
        let m = Karijera.mesavina(struka: 40, fokus: ["istorija", "sport"], udeo: [50, 30])
        XCTAssertEqual(m.map(\.broj), [4, 3, 2, 1])
        for s in [40, 50, 60, 70, 80] {
            for u in [20, 30, 40, 50] {
                XCTAssertEqual(Karijera.mesavina(struka: s, fokus: ["a", "b"], udeo: [u, u]).map(\.broj).reduce(0, +), 10)
            }
        }
        XCTAssertEqual(Karijera.stres(Sef.Nivo(tacno: 1, netacno: 3, ometanja: 3)), 0.15, accuracy: 0.0001)
    }
}
