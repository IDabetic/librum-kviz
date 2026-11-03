import XCTest
@testable import LibrumKviz

/// Isti slučajevi kao tests/osvajanje.test.mjs na vebu.
final class PravilaTests: XCTestCase {
    static let prestoniceVeba = ["PNG", "ALB", "CHE"]

    private func nova(_ seme: UInt32 = 1) -> Stanje {
        var s = Slucajno(seme: seme)
        return Stanje.nova(krugova: 10, tezina: .normalno, slucajno: &s)
    }

    /// Stanje u fazi napada sa zadatim vlasnicima, ostalo neutralno sa 1 vojskom.
    private func napad(_ vlasnici: [(String, String, Int)]) -> Stanje {
        var s = nova()
        s.faza = .napad
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        return s
    }

    func testMapaDrzavaPovezanaISimetricna() {
        XCTAssertEqual(Mapa.oblasti.count, 171)
        for o in Mapa.oblasti { for n in Mapa.susedi(o.id) { XCTAssertTrue(Mapa.susedi(n).contains(o.id)) } }
        var vidjeno: Set = ["SRB"], red = ["SRB"]
        while let x = red.popLast() { for n in Mapa.susedi(x) where vidjeno.insert(n).inserted { red.append(n) } }
        XCTAssertEqual(vidjeno.count, 171)
        XCTAssertFalse(PutanjeMape.sve["SRB"]!.isEmpty)
    }

    func testIstiGeneratorKaoVeb() {
        // mulberry32(1): prve tri vrednosti iz Node-a.
        var s = Slucajno(seme: 1)
        XCTAssertEqual(s.sledeci(), 0.6270739405881613, accuracy: 1e-12)
        XCTAssertEqual(s.sledeci(), 0.002735721180215478, accuracy: 1e-12)
        XCTAssertEqual(s.sledeci(), 0.5274470399599522, accuracy: 1e-12)
    }

    func testPocetakTriRegionaPoSestDrzava() {
        for seme: UInt32 in 1...5 {
            let s = nova(seme)
            XCTAssertEqual(Set(s.igraci.map { Mapa.oblast($0.prestonica).region }).count, 3)
            for p in s.igraci { XCTAssertEqual(s.oblastiIgraca(p.id).count, Pravila.pocetnihDrzava) }
        }
    }

    func testIstiPocetakKaoVeb() {
        // Seme 1 na vebu (node): prestonice redom za ti, mimi, zig.
        let s = nova(1)
        XCTAssertEqual(s.igraci.map(\.prestonica), PravilaTests.prestoniceVeba)
    }

    func testSnabdevanjeIRaspored() {
        let s = nova()
        XCTAssertEqual(s.snabdevanje(tacno: true).zaRaspored, 3)
        let r = s.snabdevanje(tacno: false)
        XCTAssertEqual(r.zaRaspored, 1)
        XCTAssertEqual(r.rasporedi(s.igraci[0].prestonica).faza, .napad)
    }

    func testOsvajanjeNeutralne() {
        let s = napad([("SRB", "ti", 5)])
        let (novo, ishod) = s.razresiBitku(odakle: "SRB", kuda: "BGR", napadac: Odgovor(tacan: true, ms: 1), branilac: nil)
        XCTAssertTrue(ishod.osvojeno)
        XCTAssertEqual(novo.oblasti["BGR"]?.vojske, 4)
        XCTAssertTrue(novo.mete("BGR").contains("TUR"))
    }

    func testBitkaProtivIgraca() {
        let s = napad([("SRB", "ti", 5), ("BGR", "mimi", 4)])
        XCTAssertEqual(s.razresiBitku(odakle: "SRB", kuda: "BGR", napadac: .init(tacan: true, ms: 2000), branilac: .init(tacan: true, ms: 5000)).0.oblasti["BGR"]?.vojske, 3)
        let oba = s.razresiBitku(odakle: "SRB", kuda: "BGR", napadac: .init(tacan: false, ms: 1), branilac: .init(tacan: false, ms: 1)).0
        XCTAssertEqual(oba.oblasti["SRB"]?.vojske, 4)
        XCTAssertEqual(oba.oblasti["BGR"]?.vojske, 3)
    }

    func testProbojIBonusRegiona() {
        var s = napad([("SRB", "ti", 12)])
        var tren = "SRB"
        var poslednji: Ishod?
        for meta in ["BGR", "TUR", "GRC"] {
            let r = s.razresiBitku(odakle: tren, kuda: meta, napadac: .init(tacan: true, ms: 1), branilac: nil)
            s = r.0; tren = meta; poslednji = r.1
        }
        XCTAssertEqual(poslednji?.proboj, true)
        let zev = napad(Mapa.oblasti.filter { $0.region == "zev" }.map { ($0.id, "ti", 1) })
        let bonus = Mapa.regioni.first { $0.id == "zev" }!.bonus
        // Pojačanja = max(3, države / 2) + bonus kontinenta; netačan odgovor daje pola.
        let drzava = Mapa.oblasti.filter { $0.region == "zev" }.count
        XCTAssertEqual(zev.pojacanja("ti", tacno: true), max(3, drzava / 2) + bonus)
        XCTAssertEqual(napad((0..<20).map { (Mapa.oblasti[$0 * 7].id, "ti", 1) }).pojacanja("ti", tacno: true) >= 10, true)
    }

    func testCelaPartijaBotova() {
        var rnd = Slucajno(seme: 42)
        var s = Stanje.nova(krugova: 10, tezina: .tesko, slucajno: &rnd)
        var koraka = 0
        while s.faza != .kraj && koraka < 5000 {
            koraka += 1
            s = s.snabdevanje(tacno: rnd.sledeci() < 0.6).botRasporedi()
            while let n = s.botSledeciNapad() {
                let b: Odgovor? = s.oblasti[n.kuda]?.vlasnik != nil ? s.botOdgovor(&rnd) : nil
                s = s.razresiBitku(odakle: n.odakle, kuda: n.kuda, napadac: s.botOdgovor(&rnd), branilac: b).0
            }
            s = s.zavrsiPotez()
        }
        XCTAssertEqual(s.faza, .kraj)
    }

    func testProKvizBodovanjeKaoVeb() {
        var p = ProKviz()
        for _ in 0..<5 { _ = p.odgovor(tacan: true) }
        XCTAssertEqual(p.poeni, 60) // 5 × 10 + bonus za niz od 5
        _ = p.odgovor(tacan: false)
        XCTAssertEqual(p.poeni, 55)
        XCTAssertEqual(p.zivoti, 9)
        p.aktivirajRisk()
        _ = p.odgovor(tacan: false)
        XCTAssertEqual(p.zivoti, 7)
        XCTAssertEqual(p.poeni, 45)
        XCTAssertFalse(p.riskDostupan) // isti blok od 10
    }
}

/// Pravila ostalih igara, isti brojevi kao na vebu.
final class IgreTests: XCTestCase {
    static let vebRed1 = [2, 1, 0, 3]
    static let vebRed2 = [3, 1, 2, 0]

    func testVesanjePomoci() {
        var v = Vesanje(rec: "kiša")
        v.skloniPolovinuSlova()
        let ugaseno = Vesanje.azbuka.filter { v.iskorisceno($0) }
        XCTAssertEqual(ugaseno.count, (Vesanje.azbuka.count - 4) / 2)
        XCTAssertFalse(ugaseno.contains("K"))
        XCTAssertEqual(v.zivoti, Vesanje.pocetniZivoti)
        let promasaj = Vesanje.azbuka.first { !v.iskorisceno($0) && !"KIŠA".contains($0) }!
        v.pogodi(promasaj); v.dodajZivot(); v.dodajZivot()
        XCTAssertEqual(v.zivoti, Vesanje.pocetniZivoti)
    }

    func testVesanjeSlovaIBonus() {
        var v = Vesanje(rec: "kiša")
        v.pogodi("K"); v.pogodi("I"); v.pogodi("Š")
        XCTAssertEqual(v.poeni, 15)
        v.pogodi("A")
        XCTAssertEqual(v.status, .pobeda)
        XCTAssertEqual(v.poeni, 20 + Vesanje.bonusBezGreske)
    }

    func testVesanjePromasajICelaRec() {
        var v = Vesanje(rec: "berlinski zid")
        v.pogodi("X")
        XCTAssertEqual(v.zivoti, 5)
        XCTAssertEqual(v.prikaz.filter { $0 == " " }.count, 1)
        v.pogodiRec("pogrešno")
        XCTAssertEqual(v.zivoti, 3)
        v.pogodiRec("Berlinski zid")
        XCTAssertEqual(v.status, .pobeda)
        XCTAssertEqual(v.poeni, Vesanje.bonusRec + Vesanje.bonusMaloGresaka)
    }

    func testBrziKviz() {
        let p = Pitanje(id: "x", question_text: "?", options: ["a", "b", "c", "d"], correct_answer: 2)
        let tacna = BrziKviz.Izjava(p) { 0.1 }
        XCTAssertTrue(tacna.jeTacno)
        var b = BrziKviz()
        XCTAssertTrue(b.odgovor(tacna, kaze: true))
        XCTAssertFalse(b.odgovor(tacna, kaze: nil))
        XCTAssertEqual(b.poeni, 5)
    }

    func testDuelMesanjeKaoVeb() {
        // Vrednosti iz seededShuffle na vebu (Node) za ova dva id-ja.
        XCTAssertEqual(DuelMesanje.red("31628f47-f1e2-4f92-8be0-791c3cf231e3"), IgreTests.vebRed1)
        XCTAssertEqual(DuelMesanje.red("abc"), IgreTests.vebRed2)
    }
}

/// Isti slučajevi kao v3 testovi u tests/osvajanje.test.mjs.
final class OsvajanjeV3Tests: XCTestCase {
    private func napad(_ vlasnici: [(String, String, Int)]) -> Stanje {
        var r = Slucajno(seme: 1)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        return s
    }

    func testKontinenti() {
        XCTAssertEqual(Kontinenti.svi.map { Kontinenti.oblasti($0.id).count }, [18, 12, 38, 50, 46, 7])
    }

    func testTimoviIMisije() {
        var r = Slucajno(seme: 3)
        let s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, igraci: [
            NoviIgrac(id: "a1", ime: "A1", boja: 0x12907E, covek: true, tim: "A"),
            NoviIgrac(id: "b1", ime: "B1", boja: 0xFF5FA2, covek: false, tim: "B"),
            NoviIgrac(id: "a2", ime: "A2", boja: 0x12907E, covek: false, tim: "A", kapiten: false),
            NoviIgrac(id: "b2", ime: "B2", boja: 0xFF5FA2, covek: false, tim: "B", kapiten: false),
        ], pocetak: ["A": "evr", "B": "jam"], misije: true)
        for p in s.igraci { XCTAssertEqual(Kontinenti.od(p.prestonica).id, p.tim == "A" ? "evr" : "jam") }
        XCTAssertEqual(s.oblastiIgraca("a1"), s.oblastiIgraca("a2"))
        XCTAssertNotNil(s.misije["A"]); XCTAssertNotEqual(s.misije["A"], s.misije["B"])
        XCTAssertEqual(s.napadaPoPotezu, 2)
    }

    func testBitkaSkorom() {
        let s = napad([("ESP", "ti", 6), ("FRA", "mimi", 4)])
        let (a, ishod) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 4, ms: 40000), branilac: Skor(tacnih: 3, ms: 20000))
        XCTAssertTrue(ishod.osvojeno)
        XCTAssertEqual(a.oblasti["FRA"], StanjeOblasti(vlasnik: "ti", vojske: 5))
        XCTAssertEqual(a.bonusPomoci["ti"], 2)
        let (b, poraz) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 3, ms: 30000), branilac: Skor(tacnih: 3, ms: 25000))
        XCTAssertEqual(b.oblasti["FRA"]?.vlasnik, "mimi")
        // Izgubljena bitka protiv igrača: on uzima državu iz koje se napadalo.
        XCTAssertEqual(b.oblasti["ESP"], StanjeOblasti(vlasnik: "mimi", vojske: 4))
        XCTAssertTrue(poraz.izgubljenaDrzava)
        XCTAssertEqual(s.uslovBitke("FRA").pitanja, 5)
        XCTAssertEqual(s.napadaPoPotezu, 5)
    }

    func testOdbrane() {
        var s0 = napad([("MAR", "ti", 8)])
        for id in Kontinenti.oblasti("evr") { s0.oblasti[id] = StanjeOblasti(vlasnik: "mimi", vojske: 3) }
        func sa(_ o: Odbrana) -> Stanje { var s = s0; s.odbrane = ["evr": o]; return s }
        XCTAssertEqual(sa(.prednost).razresiBitkuSkorom(odakle: "MAR", kuda: "ESP", napadac: Skor(tacnih: 4, ms: 1), branilac: Skor(tacnih: 3, ms: 9)).0.oblasti["ESP"]?.vlasnik, "mimi")
        XCTAssertEqual(sa(.zamka).razresiBitkuSkorom(odakle: "MAR", kuda: "ESP", napadac: Skor(tacnih: 1, ms: 1), branilac: Skor(tacnih: 3, ms: 9)).0.oblasti["MAR"]?.vojske, 5)
        let t = sa(.tvrdjava).razresiBitkuSkorom(odakle: "MAR", kuda: "ESP", napadac: Skor(tacnih: 5, ms: 1), branilac: Skor(tacnih: 0, ms: 9)).0
        XCTAssertEqual(t.oblasti["ESP"], StanjeOblasti(vlasnik: "mimi", vojske: 2))
        XCTAssertEqual(sa(.brzSat).uslovBitke("ESP").sekundi, Pravila.sekundiBrzSat)
    }

    func testMisijaPobedjujeOdmah() {
        var s = napad([("ESP", "ti", 9), ("FRA", "mimi", 1)])
        s.misije = ["ti": "evr-jam", "mimi": "drzava60"]
        for id in Kontinenti.oblasti("evr") + Kontinenti.oblasti("jam") where id != "FRA" { s.oblasti[id] = StanjeOblasti(vlasnik: "ti", vojske: 2) }
        let (posle, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 5, ms: 1), branilac: Skor(tacnih: 0, ms: 1))
        XCTAssertEqual(posle.pobednik, "ti")
        XCTAssertEqual(posle.faza, .kraj)
    }
}

final class OsvajanjeKontinentTests: XCTestCase {
    /// Igra na jednom kontinentu: države van njega ne postoje, pa se na njih ne može ni napasti.
    func testKontinentImaSamoSvojeDrzave() {
        var r = Slucajno(seme: 7)
        let s = Stanje.nova(krugova: 8, tezina: .normalno, slucajno: &r, igraci: Array(Stanje.podrazumevani.prefix(2)), teren: "evr")
        let evropa = Set(Kontinenti.oblasti("evr"))
        XCTAssertEqual(Set(s.oblasti.keys), evropa)
        XCTAssertTrue(s.igraci.allSatisfy { evropa.contains($0.prestonica) })
        XCTAssertTrue(s.misije.isEmpty)
        var napad = s
        napad.faza = .napad
        for id in napad.oblastiIgraca(napad.trenutni.id) { XCTAssertTrue(Set(napad.mete(id)).isSubset(of: evropa)) }
    }
}

final class OsvajanjeVezaTests: XCTestCase {
    /// Stanje putuje kao JSON između telefona; posle puta mora biti isto (mapa, misije, odbrane, redosled).
    func testStanjeKrozJsonOstajeIsto() throws {
        var r = Slucajno(seme: 11)
        var s = Stanje.nova(krugova: 8, tezina: .normalno, slucajno: &r, igraci: Array(Stanje.podrazumevani.prefix(3)), misije: true)
        s.odbrane = ["evr": .zamka]
        let d = try JSONEncoder().encode(s)
        let natrag = try JSONDecoder().decode(Stanje.self, from: d)
        XCTAssertEqual(natrag, s)
        XCTAssertLessThan(d.count, 20_000, "stanje mora ostati malo za slanje na svaki potez")
    }
}

/// Mozak bota (docs/OSVAJANJE-BOT.md): šansa bitke, koga cilja, šta bira i kad odustaje.
final class BotTests: XCTestCase {
    /// Bot „mimi” na potezu; ostalo neutralno sa 1 vojskom; „ti” je čovek.
    private func botNaPotezu(_ vlasnici: [(String, String, Int)], tacnost: Double = 0.75) -> Stanje {
        var r = Slucajno(seme: 3)
        var s = Stanje.nova(krugova: 12, tezina: .tesko, slucajno: &r)
        s.faza = .napad
        s.naPotezu = s.igraci.firstIndex { $0.id == "mimi" }!
        s.tacnostBota = tacnost
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        return s
    }

    func testSansaBitke() {
        XCTAssertEqual(Stanje.sansaBitke(0.5, 0.5, n: 5, prednost: false), 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(Stanje.sansaBitke(0.75, 0.5, n: 5, prednost: false), 0.7)
        XCTAssertLessThan(Stanje.sansaBitke(0.75, 0.5, n: 5, prednost: true), Stanje.sansaBitke(0.75, 0.5, n: 5, prednost: false))
    }

    func testBotoviCiljajuJedinogCoveka() {
        let s = botNaPotezu([("SRB", "ti", 3), ("FRA", "mimi", 3), ("CHN", "zig", 9)])
        XCTAssertEqual(s.ciljBota("mimi"), "ti")
        XCTAssertEqual(s.ciljBota("zig"), "ti")
    }

    func testBotZatvaraRegion() {
        let srb = Mapa.oblast("SRB").region
        let region = Mapa.oblasti.filter { $0.region == srb }.map(\.id)
        let s = botNaPotezu(region.filter { $0 != "SRB" }.map { ($0, "mimi", 3) })
        XCTAssertEqual(s.botSledeciNapad()?.kuda, "SRB")
    }

    func testBotNeRizikujePrestonicuKadSlaboZna() {
        var s = botNaPotezu([("FRA", "mimi", 8), ("DEU", "ti", 2)], tacnost: 0.3)
        s.igraci = s.igraci.map { var i = $0; if i.id == "mimi" { i.prestonica = "FRA" }; return i }
        XCTAssertLessThan(s.ocenaNapada(odakle: "FRA", kuda: "DEU"), 0)
    }
}

/// Sat poteza: tri isteka zaredom bez napada izbacuju igrača; napad briše niz.
final class SatPotezaTests: XCTestCase {
    func testTriIstekaIzbacuju() {
        var r = Slucajno(seme: 5)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        let ja = s.trenutni.id
        let tim = s.trenutni.tim
        for i in 1...3 {
            s = s.isteklo(ja)
            XCTAssertEqual(s.propusteno?[ja], i)
            // Ostali igrači odigraju svoje poteze, pa je opet red na mene.
            while s.trenutni.id != ja && s.faza != .kraj { s = s.zavrsiPotez() }
            s.faza = .napad
        }
        XCTAssertTrue(s.igraci.first { $0.id == ja }!.ispao)
        XCTAssertFalse(s.oblasti.values.contains { $0.vlasnik == tim })
    }

    func testNapadBriseNiz() {
        var r = Slucajno(seme: 5)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        let ja = s.trenutni.id
        s = s.isteklo(ja)
        while s.trenutni.id != ja { s = s.zavrsiPotez() }
        s.faza = .napad; s.bitaka = 1
        XCTAssertEqual(s.isteklo(ja).propusteno?[ja], 0)
    }
}
