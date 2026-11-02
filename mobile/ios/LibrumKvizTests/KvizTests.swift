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
        XCTAssertTrue(p.allSatisfy { $0.options.count == 4 && $0.slika?.hasPrefix("https://") == true })
        XCTAssertEqual(Set(p.map(\.id)).count, 10)
    }
}
