import XCTest
@testable import LibrumKviz

final class KlasicniKvizTests: XCTestCase {
    private let p = Prikaz(tekst: "?", opcije: ["a", "b", "c", "d"], tacan: 2)

    func testTacanOdgovorDonosiOsnovuIBrzinu() {
        var k = KlasicniKviz()
        let r = k.odgovor(p, izabran: 2, ostaloSekundi: 7.6, ms: 7400)
        XCTAssertEqual(r.ukupno, 100 + 7 * 2)
        XCTAssertEqual(r.niz, 0)
    }

    func testNizOdTrecegTacnogDajeBonus() {
        var k = KlasicniKviz()
        k.odgovor(p, izabran: 2, ostaloSekundi: 0, ms: 1)
        k.odgovor(p, izabran: 2, ostaloSekundi: 0, ms: 1)
        XCTAssertEqual(k.odgovor(p, izabran: 2, ostaloSekundi: 0, ms: 1).ukupno, 120)
        k.odgovor(p, izabran: 0, ostaloSekundi: 0, ms: 1)
        XCTAssertEqual(k.niz, 0)
        XCTAssertEqual(k.najduziNiz, 3)
    }

    func testPreskokNijeNetacan() {
        var k = KlasicniKviz()
        k.preskok(p)
        XCTAssertEqual(k.netacnih, 0)
        XCTAssertEqual(k.zapisi.count, 1)
    }

    func testZvezdice() {
        XCTAssertEqual(KlasicniKviz.zvezdice(tacnih: 10, od: 10), 3)
        XCTAssertEqual(KlasicniKviz.zvezdice(tacnih: 7, od: 10), 2)
        XCTAssertEqual(KlasicniKviz.zvezdice(tacnih: 4, od: 10), 1)
        XCTAssertEqual(KlasicniKviz.zvezdice(tacnih: 3, od: 10), 0)
    }
}

@MainActor
final class NapredakTests: XCTestCase {
    func testNivoPoXP() {
        XCTAssertEqual(Napredak.nivo(xp: 0).nivo, 1)
        XCTAssertEqual(Napredak.nivo(xp: 249).nivo, 1)
        XCTAssertEqual(Napredak.nivo(xp: 250).nivo, 2)
        XCTAssertEqual(Napredak.nivo(xp: 250 + 500).nivo, 3)
    }

    func testPrvaIgraOtkljucavaBedzINiz() {
        let n = Napredak.deljeni
        n.resetuj()
        let ishod = n.zabeleziIgru(kviz: "opste", tacnih: 10, netacnih: 0)
        XCTAssertTrue(ishod.noviBedzevi.contains { $0.id == "prvi" })
        XCTAssertTrue(ishod.noviBedzevi.contains { $0.id == "savrseno" })
        XCTAssertEqual(n.s.nizDana, 1)
        XCTAssertEqual(n.s.najbolje["opste"], 10)
        n.resetuj()
    }

    func testDnevniFondPomociSedamZaSveIgreIPuniSePosle24h() {
        let n = Napredak.deljeni
        n.resetuj()
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(n.pomociOstalo(sada: t), 7)
        for _ in 0..<7 { XCTAssertTrue(n.iskoristiPomoc(sada: t)) }
        XCTAssertFalse(n.iskoristiPomoc(sada: t.addingTimeInterval(3600)))
        XCTAssertEqual(n.pomociOstalo(sada: t.addingTimeInterval(23 * 3600)), 0)
        XCTAssertEqual(n.sledeciFondPomoci(sada: t), t.addingTimeInterval(24 * 3600))
        XCTAssertEqual(n.pomociOstalo(sada: t.addingTimeInterval(24 * 3600)), 7)
        XCTAssertTrue(n.iskoristiPomoc(sada: t.addingTimeInterval(24 * 3600)))
        n.resetuj()
    }
}

final class NapredakCuvanjeTests: XCTestCase {
    func testStaroStanjeBezNovihPoljaSeUcitava() throws {
        let staro = #"{"xp":300,"igara":4,"uvodZavrsen":true,"novcici":120,"dani":{},"kategorije":{},"najbolje":{"opste":7},"poruke":[],"bedzevi":{}}"#
        let s = try XCTUnwrap(Napredak.ucitaj(Data(staro.utf8)))
        XCTAssertEqual(s.xp, 300)
        XCTAssertTrue(s.uvodZavrsen)
        XCTAssertEqual(s.najbolje["opste"], 7)
        XCTAssertEqual(s.pomociIskorisceno, 0)
    }
}

final class SlikariTests: XCTestCase {
    func testPaketSlikaDajeDesetIspravnihPitanja() throws {
        let p = try PaketPitanja.slikari(broj: 10, tesko: false)
        XCTAssertEqual(p.count, 10)
        // Vlasnik 03.11: svako pitanje ima sliku, i to direktnu adresu (bez sporog Special:FilePath).
        XCTAssertTrue(p.allSatisfy { $0.options.count == 4 && $0.slika?.hasPrefix("https://") == true })
        XCTAssertEqual(Set(p.map(\.id)).count, 10)
        let sva = try PaketPitanja.slikari(broj: 2000, tesko: false)
        XCTAssertGreaterThan(sva.count, 1100)
        XCTAssertFalse(sva.contains { $0.slika == nil || $0.slika!.contains("Special:FilePath") }, "pitanje bez slike ne ide u Slikare")
        XCTAssertFalse(sva.contains { $0.question_text.contains("„The ") }, "naziv ne sme ostati na engleskom")
    }
}

/// Vlasnik 03.11: pitanja se nigde ne ponavljaju; dopuna špila ne vraća već dodato pitanje.
final class SpilTests: XCTestCase {
    private func p(_ id: String) -> Pitanje { Pitanje(id: id, question_text: "Pitanje \(id)?", options: ["a", "b", "c", "d"], correct_answer: 0) }

    func testDopunaPreskaceVecVidjenaIProduzavaSpil() {
        var s = Spil([p("1"), p("2")])
        _ = s.sledece(); _ = s.sledece()
        XCTAssertEqual(s.ostalo, 0)
        XCTAssertEqual(s.dodaj([p("2"), p("3"), p("4")]), 2)
        XCTAssertEqual(s.ostalo, 2)
        XCTAssertEqual([s.sledece(), s.sledece()].map(\.tekst), ["Pitanje 3?", "Pitanje 4?"])
    }

    func testPitanjeIzbacenoPoTemiSeNeVracaDopunom() {
        var s = Spil([Pitanje(id: "1", question_text: "Prvo?", options: ["a", "b", "c", "d"], correct_answer: 0, genre: "Sport")])
        XCTAssertNotNil(s.sledece(tema: "Sport"))
        XCTAssertEqual(s.dodaj([Pitanje(id: "1", question_text: "Prvo?", options: ["a", "b", "c", "d"], correct_answer: 0, genre: "Sport")]), 0)
    }
}


/// Brzi kviz (vlasnik 03.11): niz množi poene, poslednjih 10 s duplo, greška prekida niz.
final class BrziKvizMnozilacTests: XCTestCase {
    private let tacna = BrziKviz.Izjava(Pitanje(id: "1", question_text: "?", options: ["a", "b", "c", "d"], correct_answer: 0), nasumicno: { 0 })

    func testNizMnoziIGreskaGaPrekida() {
        var b = BrziKviz()
        for _ in 0..<3 { _ = b.odgovor(tacna, kaze: true) }           // 10 + 10 + 10
        XCTAssertEqual(b.mnozilac, 2)
        _ = b.odgovor(tacna, kaze: true)                                  // +20
        XCTAssertEqual(b.poeni, 50)
        _ = b.odgovor(tacna, kaze: false)                                 // −5, niz 0
        XCTAssertEqual(b.niz, 0); XCTAssertEqual(b.mnozilac, 1); XCTAssertEqual(b.poeni, 45)
    }

    func testZavrsnicaDuplira() {
        var b = BrziKviz()
        _ = b.odgovor(tacna, kaze: true, zavrsnica: true)
        XCTAssertEqual(b.poeni, 20)
    }
}

/// Takmičenje 2–8 igrača (vlasnik 03.11): bodovanje, botovi isti na svakom telefonu, tabela i timovi.
final class TakmicenjeTests: XCTestCase {
    /// Botovi u sobi moraju biti isti na iPhonu i Androidu (PravilaTest.kt, TakmicenjeBotTest).
    func testBotIstiKaoAndroid() {
        let otisak = IgraTakmicenja.allCases.map { g -> String in
            let b = Takmicenje.Bot.rezultat(igra: g, tezina: "normalno", seme: 1095258902, mesto: 2, broj: g.broj, proteklo: 40)
            return "\(g.rawValue)=\(b.poeni)/\(b.tacnih)/\(b.odigrano)"
        }.joined(separator: ",")
        XCTAssertEqual(otisak, "pro=48/3/3,book=48/3/3,slikari=48/3/3,brzi=205/11/14,vesanje=36/1/1,premetaljka=26/0/4,pet_slova=19/0/3,lanac=19/0/3,sifra=13/0/2,ukrstenica=13/0/2,zmija=15/0/2")
    }

    func testBrziTacanNosiVise() {
        XCTAssertEqual(Takmicenje.poeni(tacno: true, ms: 4_000), 18)
        XCTAssertEqual(Takmicenje.poeni(tacno: true, ms: 20_000), 10)
        XCTAssertEqual(Takmicenje.poeni(tacno: false, ms: 1_000), 0)
    }

    func testBotIstiZaIstoSemeIRasteSaVremenom() {
        for igra in IgraTakmicenja.allCases {
            let a = Takmicenje.Bot.rezultat(igra: igra, tezina: "normalno", seme: 42, mesto: 2, broj: igra.broj, proteklo: 30)
            let b = Takmicenje.Bot.rezultat(igra: igra, tezina: "normalno", seme: 42, mesto: 2, broj: igra.broj, proteklo: 30)
            XCTAssertEqual(a, b, igra.naziv)
            let kraj = Takmicenje.Bot.rezultat(igra: igra, tezina: "normalno", seme: 42, mesto: 2, broj: igra.broj, proteklo: .infinity)
            XCTAssertTrue(kraj.gotov, igra.naziv)
            XCTAssertGreaterThanOrEqual(kraj.odigrano, a.odigrano, igra.naziv)
            XCTAssertEqual(Takmicenje.Bot.rezultat(igra: igra, tezina: "normalno", seme: 42, mesto: 2, broj: igra.broj, proteklo: 0).odigrano, 0)
        }
    }

    func testTezBotJeJaciURoseku() {
        func zbir(_ t: String) -> Int {
            (0..<200).reduce(0) { $0 + Takmicenje.Bot.rezultat(igra: .pro, tezina: t, seme: Int64($1), mesto: 1, broj: 10, proteklo: .infinity).poeni }
        }
        XCTAssertLessThan(zbir("lako"), zbir("normalno"))
        XCTAssertLessThan(zbir("normalno"), zbir("tesko"))
    }

    func testTabelaITimovi() throws {
        let json = """
        {"id":"x","kod":"ABC234","igra":"pro","domacin":"a","velicina":4,"nacin":"timovi","protivnici":"mesano","tezina":"normalno","seme":7,"broj":10,"status":"kraj",
         "mesta":[{"mesto":0,"user_id":"a","bot":null,"pozvan":false,"tim":0,"nadimak":"Ja","avatar":null,"poeni":90,"tacnih":6,"odigrano":10,"ms":1,"gotov":true},
                  {"mesto":1,"user_id":"b","bot":null,"pozvan":false,"tim":1,"nadimak":"Ona","avatar":null,"poeni":40,"tacnih":3,"odigrano":10,"ms":1,"gotov":true},
                  {"mesto":2,"user_id":null,"bot":"Mimi","pozvan":false,"tim":0,"nadimak":"Mimi","avatar":null,"poeni":0,"tacnih":0,"odigrano":0,"ms":0,"gotov":false},
                  {"mesto":3,"user_id":null,"bot":"Zig","pozvan":false,"tim":1,"nadimak":"Zig","avatar":null,"poeni":0,"tacnih":0,"odigrano":0,"ms":0,"gotov":false}]}
        """
        let s = try JSONDecoder().decode(Takmicenje.Soba.self, from: Data(json.utf8))
        let r = Takmicenje.tabela(s, ja: "a", proteklo: .infinity)
        XCTAssertEqual(r.count, 4)
        XCTAssertTrue(r.allSatisfy(\.gotov))
        XCTAssertEqual(r.filter(\.ja).map(\.ime), ["Ja"])
        XCTAssertEqual(zip(r, r.dropFirst()).allSatisfy { $0.poeni >= $1.poeni }, true)
        let t = Takmicenje.timovi(r)
        XCTAssertEqual(t.count, 2)
        XCTAssertEqual(t.map(\.poeni).reduce(0, +), r.map(\.poeni).reduce(0, +))
        XCTAssertEqual(Takmicenje.imeTima(1), "Tim B")
    }
}
