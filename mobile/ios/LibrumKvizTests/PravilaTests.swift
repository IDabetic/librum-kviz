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
        // Bez vrsta vojske, da prednosti Legije i Garde ne mešaju osnovna pravila.
        s.igraci = s.igraci.map { var i = $0; i.vojska = nil; return i }
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
        XCTAssertEqual(s.napadaPoPotezu, 2 + (s.trenutni.vojska == .konjica ? Pravila.napadaViseKonjica : 0))
    }

    func testBitkaSkorom() {
        // 5 vojski u napadu protiv 5: bez prednosti vojske.
        let s = napad([("ESP", "ti", 6), ("FRA", "mimi", 5)])
        let (a, ishod) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 4, ms: 40000), branilac: Skor(tacnih: 3, ms: 20000))
        XCTAssertTrue(ishod.osvojeno)
        XCTAssertEqual(a.oblasti["FRA"], StanjeOblasti(vlasnik: "ti", vojske: 5))
        XCTAssertEqual(a.karte("ti").count, 1, "pobeda nad igračem donosi ratnu kartu")
        XCTAssertEqual(a.pobedaBitaka?["ti"], 1)
        let (b, poraz) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 3, ms: 30000), branilac: Skor(tacnih: 3, ms: 25000))
        XCTAssertEqual(b.oblasti["FRA"]?.vlasnik, "mimi")
        // Izgubljena bitka protiv igrača: on uzima državu iz koje se napadalo.
        XCTAssertEqual(b.oblasti["ESP"], StanjeOblasti(vlasnik: "mimi", vojske: 4))
        XCTAssertTrue(poraz.izgubljenaDrzava)
        XCTAssertEqual(s.uslovBitke("FRA").pitanja, 5)
        XCTAssertEqual(s.napadaPoPotezu, 5)
    }

    func testOdbrane() {
        var s0 = napad([("MAR", "ti", 4)])
        for id in Kontinenti.oblasti("evr") { s0.oblasti[id] = StanjeOblasti(vlasnik: "mimi", vojske: 3) }
        func sa(_ o: Odbrana) -> Stanje { var s = s0; s.odbrane = ["evr": o]; return s }
        XCTAssertEqual(sa(.prednost).razresiBitkuSkorom(odakle: "MAR", kuda: "ESP", napadac: Skor(tacnih: 4, ms: 1), branilac: Skor(tacnih: 3, ms: 9)).0.oblasti["ESP"]?.vlasnik, "mimi")
        XCTAssertEqual(sa(.zamka).razresiBitkuSkorom(odakle: "MAR", kuda: "ESP", napadac: Skor(tacnih: 1, ms: 1), branilac: Skor(tacnih: 3, ms: 9)).0.oblasti["MAR"]?.vojske, 1)
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
        XCTAssertGreaterThan(Stanje.sansaBitke(0.5, 0.5, n: 5, prednost: false, pomak: 2), 0.8, "prednost vojske podiže šansu")
    }

    /// Vlasnik 03.11: botovi ne idu samo na čoveka; cilj je najjači sused, bio on čovek ili bot.
    func testBotoviCiljajuRavnopravno() {
        let s = botNaPotezu([("SRB", "ti", 3), ("FRA", "mimi", 3), ("DEU", "zig", 9)])
        XCTAssertEqual(s.ciljBota("mimi"), "zig")
        XCTAssertEqual(s.ciljBota("zig"), "mimi")
        let jak = botNaPotezu([("HUN", "ti", 12), ("ROU", "mimi", 3), ("UKR", "zig", 2)])
        XCTAssertEqual(jak.ciljBota("mimi"), "ti", "jak čovek u susedstvu je cilj kao i svaki drugi")
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

/// Napredak (docs/NAPREDAK.md): XP, titule i dnevni fond pomoći.
@MainActor
final class NapredakPravilaTests: XCTestCase {
    func testXpINiz() {
        XCTAssertEqual(Napredak.xpZaPartiju(tacnih: 8, pobeda: false, niz: 1), 100)
        XCTAssertEqual(Napredak.xpZaPartiju(tacnih: 8, pobeda: true, niz: 1), 150)
        XCTAssertEqual(Napredak.xpZaPartiju(tacnih: 8, pobeda: false, niz: 11), 150)
        XCTAssertEqual(Napredak.xpZaPartiju(tacnih: 8, pobeda: false, niz: 40), 150)
    }
    func testFondPomoci() {
        XCTAssertEqual(Napredak.fond(nivo: 1, niz: 1), 7)
        XCTAssertEqual(Napredak.fond(nivo: 6, niz: 3), 9)
        XCTAssertEqual(Napredak.fond(nivo: 30, niz: 7), 12)
    }
    func testTitule() {
        XCTAssertEqual(Napredak.titula(1), "Početnik")
        XCTAssertEqual(Napredak.titula(12), "Erudita")
        XCTAssertEqual(Napredak.titula(40), "Legenda")
    }
}

/// Strategija (vlasnik 03.11.2026, docs/OSVAJANJE-STRATEGIJA.md): prednost vojske, vrste vojske, karte, savezi, događaji, misije.
final class StrategijaTests: XCTestCase {
    private func napad(_ vlasnici: [(String, String, Int)], vojske: [String: VrstaVojske] = [:]) -> Stanje {
        var r = Slucajno(seme: 1)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        s.igraci = s.igraci.map { var i = $0; i.vojska = vojske[i.id]; return i }
        s.karteTimova = [:]
        return s
    }

    func testVisakVojskeDajePrednost() {
        // 4 vojske u napadu (5 u državi) protiv 1: +2 tačna, pa i 2 prema 3 osvaja.
        let s = napad([("ESP", "ti", 5), ("FRA", "mimi", 1)])
        XCTAssertEqual(s.pomakBitke(odakle: "ESP", kuda: "FRA"), 2)
        XCTAssertTrue(s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 2, ms: 9), branilac: Skor(tacnih: 3, ms: 1)).1.osvojeno)
        // Obrnuto: branilac sa viškom vojske ima prednost.
        let slab = napad([("ESP", "ti", 2), ("FRA", "mimi", 6)])
        XCTAssertEqual(slab.pomakBitke(odakle: "ESP", kuda: "FRA"), -2)
        XCTAssertFalse(slab.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 4, ms: 1), branilac: Skor(tacnih: 3, ms: 9)).1.osvojeno)
    }

    func testJakaVojskaNeGubiNaNeutralnoj() {
        let s = napad([("ESP", "ti", 4)])
        let (posle, ishod) = s.razresiBitku(odakle: "ESP", kuda: "FRA", napadac: Odgovor(tacan: false, ms: 1), branilac: nil)
        XCTAssertEqual(ishod.gubitakNapadaca, 0)
        XCTAssertEqual(posle.oblasti["ESP"]?.vojske, 4)
        let slaba = napad([("ESP", "ti", 3)]).razresiBitku(odakle: "ESP", kuda: "FRA", napadac: Odgovor(tacan: false, ms: 1), branilac: nil)
        XCTAssertEqual(slaba.1.gubitakNapadaca, 1)
    }

    func testLegijaGardaKonjicaMudraci() {
        let jednako = [("ESP", "ti", 4), ("FRA", "mimi", 3)]
        XCTAssertEqual(napad(jednako, vojske: ["ti": .legija]).pomakBitke(odakle: "ESP", kuda: "FRA"), 1)
        XCTAssertEqual(napad(jednako, vojske: ["mimi": .garda]).pomakBitke(odakle: "ESP", kuda: "FRA"), -1)
        let konjica = napad(jednako, vojske: ["ti": .konjica])
        XCTAssertEqual(konjica.napadaPoPotezu, Pravila.bitakaPoPotezu + Pravila.napadaViseKonjica)
        XCTAssertEqual(napad(jednako, vojske: ["ti": .mudraci]).uslovBitke("FRA", za: "ti").sekundi, Pravila.sekundiPoPitanju + Pravila.sekundiMudraci)
        XCTAssertEqual(Pravila.sekundiPoPitanju, 20)
    }

    func testGraditeljiDobijajuViseVojske() {
        let srb = Mapa.oblast("SRB").region
        let region = Mapa.oblasti.filter { $0.region == srb }.map { ($0.id, "ti", 2) }
        let obicni = napad(region).pojacanja("ti", tacno: true)
        XCTAssertEqual(napad(region, vojske: ["ti": .graditelji]).pojacanja("ti", tacno: true), obicni + 1)
    }

    func testKartePojacanjeIZamrzni() {
        var s = napad([("ESP", "ti", 3), ("FRA", "mimi", 3)])
        s.karteTimova = ["ti": [.pojacanje, .zamrzni]]
        let p = s.igrajPojacanje("ESP")!
        XCTAssertEqual(p.oblasti["ESP"]?.vojske, 5)
        XCTAssertEqual(p.karte("ti"), [.zamrzni])
        XCTAssertNil(p.igrajPojacanje("ESP"), "nema više karte")
        let z = p.igrajZamrzni("ESP")!
        XCTAssertTrue(z.jeZamrznuta("ESP"))
        // Rival ne može da napadne zamrznutu državu.
        var mimi = z
        mimi.naPotezu = mimi.igraci.firstIndex { $0.id == "mimi" }!
        XCTAssertFalse(mimi.mete("FRA").contains("ESP"))
    }

    func testNajviseKarata() {
        var s = napad([])
        for _ in 0..<10 { s.dodeliKartu("ti") }
        XCTAssertEqual(s.karte("ti").count, Pravila.najviseKarata)
    }

    func testSavezBraniNapad() {
        var s = napad([("ESP", "ti", 5), ("FRA", "mimi", 2)])
        XCTAssertTrue(s.mete("ESP").contains("FRA"))
        s = s.predloziSavez(od: "ti", za: "mimi")
        XCTAssertFalse(s.uSavezu("ti", "mimi"), "jednostran predlog nije savez")
        s = s.predloziSavez(od: "mimi", za: "ti")
        XCTAssertTrue(s.uSavezu("ti", "mimi"))
        XCTAssertFalse(s.mete("ESP").contains("FRA"))
        s.krug += 2
        XCTAssertTrue(s.uSavezu("ti", "mimi"), "vlasnik 04.11: savez traje do raskida ili izdaje")
    }

    func testDogadjajSvakaCetiriKruga() {
        var s = napad([("ESP", "ti", 3)])
        s.krug = Pravila.dogadjajSvakih
        s.pokreniDogadjajAkoTreba()
        let d = try! XCTUnwrap(s.dogadjaj)
        XCTAssertTrue(s.aktivanDogadjaj(d.kontinent))
        XCTAssertNotNil(Dogadjaj.opis[d.kontinent])
        XCTAssertEqual(Set(Dogadjaj.opis.keys), Set(Kontinenti.svi.map(\.id)), "svaki kontinent ima svoj događaj")
        var monsun = napad([("IND", "ti", 5)])
        monsun.dogadjaj = Dogadjaj(kontinent: "azi", od: monsun.krug, doKruga: monsun.krug)
        XCTAssertTrue(monsun.mete("IND").isEmpty, "Monsun: u Aziji nema napada")
    }

    func testMisijeImajuNapredakINePonavljajuSe() {
        XCTAssertGreaterThanOrEqual(Misije.sve.count, 28)
        XCTAssertEqual(Set(Misije.sve.map(\.id)).count, Misije.sve.count)
        var s = napad([("ESP", "ti", 3), ("FRA", "mimi", 3)])
        for m in Misije.sve {
            s.misije = ["ti": m.id]
            let n = s.napredakMisije("ti")
            XCTAssertTrue((0...1).contains(n), m.id)
        }
        // Misije iz ove nedelje idu na kraj reda: sa dovoljno ponude čovek ih ne dobija.
        let skoro = Set(Misije.sve.prefix(20).map(\.id))
        var r = Slucajno(seme: 9)
        let nova = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, misije: true, izbegniMisije: skoro)
        XCTAssertFalse(skoro.contains(nova.misije["ti"] ?? ""))
    }

    func testStanjeSaStrategijomKrozJson() throws {
        var s = napad([("ESP", "ti", 3)], vojske: ["ti": .izvidnica])
        s.karteTimova = ["ti": [.spijun]]
        s = s.predloziSavez(od: "ti", za: "zig", prihvata: true).posalji("Savez?", od: "ti")
        s.dogadjaj = Dogadjaj(kontinent: "evr", od: 4, doKruga: 5)
        let natrag = try JSONDecoder().decode(Stanje.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(natrag, s)
    }
}

/// Drugi talas strategije (Strategija2.swift): teren, snabdevanje, čuda, magla, ulog, marš, pohod, izdaja, trgovina, ultimatum.
final class Strategija2Tests: XCTestCase {
    private func napad(_ vlasnici: [(String, String, Int)]) -> Stanje {
        var r = Slucajno(seme: 1)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        s.igraci = s.igraci.map { var i = $0; i.vojska = nil; return i }
        s.karteTimova = [:]
        return s
    }

    func testPlanineIMore() {
        // Italija (4 u napadu) na Švajcarsku (planine, 3): višak 0, planine −1.
        let s = napad([("ITA", "ti", 4), ("CHE", "mimi", 3)])
        XCTAssertEqual(s.pomakBitke(odakle: "ITA", kuda: "CHE"), -1)
        XCTAssertFalse(Teren.more.isEmpty)
        let par = Mapa.more[0]
        let m = napad([(par.a, "ti", 4), (par.b, "mimi", 3)])
        XCTAssertLessThanOrEqual(m.pomakBitke(odakle: par.a, kuda: par.b), -1, "napad preko mora traži tačan više")
    }

    func testPustinjaKostaVojsku() {
        let s = napad([("LBY", "ti", 6), ("EGY", "mimi", 6)])
        let (posle, _) = s.razresiBitkuSkorom(odakle: "LBY", kuda: "EGY", napadac: Skor(tacnih: 0, ms: 1), branilac: Skor(tacnih: 5, ms: 1))
        XCTAssertEqual(posle.oblasti["LBY"]?.vojske, 6 - Pravila.gubitakPorazenogNapadaca - 1)
    }

    func testOdseceneNemajuPojacanja() {
        var s = napad([("FRA", "ti", 3), ("ESP", "ti", 3), ("POL", "ti", 3)])
        s.igraci = s.igraci.map { var i = $0; if i.id == "ti" { i.prestonica = "FRA" }; return i }
        XCTAssertEqual(s.odsecene("ti"), ["POL"])
        s.naPotezu = s.igraci.firstIndex { $0.id == "ti" }!
        s.faza = .snabdevanje
        let posle = s.snabdevanje(tacno: true)
        XCTAssertEqual(posle.oblasti["POL"]?.vojske, 2, "odsečena gubi vojsku")
        XCTAssertEqual(posle.rasporedi("POL"), posle, "u odsečenu se ne raspoređuje")
        XCTAssertNotEqual(posle.rasporedi("FRA"), posle)
    }

    func testCuda() {
        var s = napad([("EGY", "ti", 3), ("USA", "ti", 3)])
        s.naPotezu = s.igraci.firstIndex { $0.id == "ti" }!
        let bez = napad([("LBY", "ti", 3), ("CAN", "ti", 3)])
        XCTAssertEqual(s.napadaPoPotezu, Pravila.bitakaPoPotezu + 1, "Kip slobode: napad više")
        XCTAssertEqual(Set(Cudo.sva.map { Kontinenti.od($0.oblast).id }).count, 6, "jedno čudo po kontinentu")
        var a = s; a.faza = .snabdevanje
        var b = bez; b.faza = .snabdevanje; b.naPotezu = a.naPotezu
        XCTAssertEqual(a.snabdevanje(tacno: true).zaRaspored, b.snabdevanje(tacno: true).zaRaspored + Pravila.vojskiPiramide)
    }

    func testMagla() {
        let s = napad([("FRA", "ti", 3), ("ESP", "mimi", 3), ("CHN", "mimi", 7)])
        XCTAssertTrue(s.vidi("ti", "ESP"))
        XCTAssertFalse(s.vidi("ti", "CHN"))
        var p = s; p.oblasti["PER"] = StanjeOblasti(vlasnik: "ti", vojske: 1)
        XCTAssertTrue(p.vidi("ti", "CHN"), "Maču Pikču skida maglu")
        XCTAssertEqual(Stanje.procenaVojske(7), "6+")
    }

    func testUlog() {
        let s = napad([("ESP", "ti", 6), ("FRA", "mimi", 5), ("DEU", "mimi", 5)]).postaviUlog(2)
        let (pobeda, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 5, ms: 1), branilac: Skor(tacnih: 0, ms: 1))
        XCTAssertEqual(pobeda.oblasti["FRA"]?.vojske, 5 + 2)
        XCTAssertEqual(pobeda.oblasti["DEU"]?.vojske, 3)
        XCTAssertNil(pobeda.ulog, "ulog važi samo za jednu bitku")
    }

    func testMars() {
        var s = napad([("ESP", "ti", 6), ("FRA", "ti", 1), ("DEU", "ti", 1), ("POL", "ti", 1)])
        s.naPotezu = s.igraci.firstIndex { $0.id == "ti" }!
        XCTAssertTrue(s.dometMarsa("ESP").contains("DEU"))
        let m = s.utvrdi(odakle: "ESP", kuda: "DEU", broj: 5)
        XCTAssertEqual(m.oblasti["DEU"]?.vojske, 6)
        XCTAssertEqual(m.oblasti["ESP"]?.vojske, 1)
    }

    func testPohod() {
        let srb = Mapa.oblast("SRB").region
        let region = Mapa.oblasti.filter { $0.region == srb }.map(\.id)
        var s = napad([(region[0], "ti", 3)])
        s.naPotezu = s.igraci.firstIndex { $0.id == "ti" }!
        s = s.najaviPohod(srb)!
        XCTAssertNil(s.najaviPohod(srb), "jedan pohod odjednom")
        for id in region { s.oblasti[id] = StanjeOblasti(vlasnik: "ti", vojske: 2) }
        XCTAssertEqual(s.proveriPohod("ti"), Pravila.nagradaPohoda)
        XCTAssertEqual(s.karte("ti").count, 1)
        XCTAssertNil(s.pohodi?["ti"])
    }

    func testIzdajaITrgovina() {
        var s = napad([("ESP", "ti", 5), ("FRA", "mimi", 2)])
        s = s.predloziSavez(od: "ti", za: "mimi", prihvata: true)
        s.karteTimova = ["ti": [.pojacanje], "mimi": [.sabotaza]]
        let (r, dobio) = try! XCTUnwrap(s.razmeniKartu(od: "ti", sa: "mimi", daje: .pojacanje))
        XCTAssertEqual(dobio, .sabotaza)
        XCTAssertEqual(r.karte("mimi"), [.pojacanje])
        XCTAssertEqual(r.meteIzdaje("ESP"), ["FRA"])
        let iz = r.izdaj("ti", "mimi")
        XCTAssertTrue(iz.jeIzdajnik("ti"))
        XCTAssertTrue(iz.karte("ti").isEmpty)
        XCTAssertTrue(iz.mete("ESP").contains("FRA"))
        XCTAssertFalse(iz.botPrihvataSavez(bot: "zig", od: "ti"), "sa izdajnikom nema saveza")
    }

    func testUltimatum() {
        var slab = napad([("ESP", "ti", 9), ("FRA", "ti", 9), ("DEU", "ti", 9), ("PRT", "mimi", 1), ("MAR", "mimi", 1)])
        slab.naPotezu = slab.igraci.firstIndex { $0.id == "ti" }!
        let (s, prihvaceno) = try! XCTUnwrap(slab.ultimatum("PRT"))
        XCTAssertTrue(prihvaceno)
        XCTAssertEqual(s.oblasti["PRT"]?.vlasnik, "ti")
        XCTAssertNil(s.ultimatum("MAR"), "jedan ultimatum po potezu")
        var jak = napad([("ESP", "ti", 3), ("FRA", "mimi", 3), ("ITA", "mimi", 3)])
        jak.naPotezu = jak.igraci.firstIndex { $0.id == "ti" }!
        XCTAssertNil(jak.ultimatum("FRA"), "jačem se ne šalje ultimatum")
    }

    /// Vlasnik 03.11: na svakom kontinentu svaka država mora moći da se napadne (Francuska Gvajana, Trinidad i Tobago).
    func testSvakiKontinentPovezan() {
        for k in Kontinenti.svi {
            let ids = Set(Kontinenti.oblasti(k.id))
            var vidjeno: Set<String> = [], red = [ids.first!]
            while let x = red.popLast() {
                guard vidjeno.insert(x).inserted else { continue }
                red += Mapa.susedi(x).filter { ids.contains($0) && !vidjeno.contains($0) }
            }
            XCTAssertEqual(vidjeno, ids, "\(k.ime): \(ids.subtracting(vidjeno).sorted())")
        }
        // Francuska nema deo u Južnoj Americi (x < 900 na mapi).
        XCTAssertGreaterThan(PutanjeMape.sve["FRA"]!.boundingRect.minX, 800)
    }

    func testPomociVojskeJednomPoKrugu() {
        var s = napad([("ESP", "ti", 5)])
        s.igraci = s.igraci.map { var i = $0; if i.id == "ti" { i.vojska = .garda }; return i }
        XCTAssertEqual(VrstaVojske.allCases.map { $0.pomoci.count }, Array(repeating: 3, count: 6))
        XCTAssertEqual(Set(VrstaVojske.allCases.map(\.moc)).count, 6, "svaka vojska ima svoju moć")
        XCTAssertEqual(Set(VrstaVojske.allCases.flatMap(\.pomoci)).count, 18, "vlasnik 04.11: nijedna moć se ne ponavlja")
        let a = try! XCTUnwrap(s.iskoristiPomocVojske("ti", .stit))
        XCTAssertNil(a.iskoristiPomocVojske("ti", .stit), "drugi put u istom krugu ne može")
        XCTAssertNil(a.iskoristiPomocVojske("ti", .juris), "tuđa pomoć ne može")
        var b = a; b.krug += 1
        XCTAssertNotNil(b.iskoristiPomocVojske("ti", .stit), "u sledećem krugu opet može")
    }

    /// Sa šestoro misija traži pola država (mapa je podeljena na više delova); tekst prati prag.
    func testMisijePremaBrojuStrana() {
        var r = Slucajno(seme: 2)
        let sest = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, igraci: (0..<6).map { NoviIgrac(id: "p\($0)", ime: "P\($0)", boja: 0, covek: $0 == 0) })
        XCTAssertEqual(sest.prag(60), 30)
        XCTAssertEqual(sest.tekstMisije("drzava60"), "Drži 30 država.")
        XCTAssertEqual(sest.tekstMisije("tacnih40"), Misije.tekst("tacnih40"), "tačni odgovori se ne skaliraju")
        var r2 = Slucajno(seme: 2)
        XCTAssertEqual(Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r2).prag(60), 60)
        // Vlasnik 04.11: 30 krugova vraća pune pragove i sa šestoro.
        var r3 = Slucajno(seme: 2)
        XCTAssertEqual(Stanje.nova(krugova: 30, tezina: .normalno, slucajno: &r3, igraci: (0..<6).map { NoviIgrac(id: "p\($0)", ime: "P\($0)", boja: 0, covek: $0 == 0) }).prag(60), 60)
    }

    func testSpilTeme() {
        var spil = Spil((0..<12).map { i in Pitanje(id: "p\(i)", question_text: "?", options: ["a", "b", "c", "d"], correct_answer: 0, genre: i < 6 ? "Istorija" : "Sport") })
        XCTAssertEqual(Set(spil.teme(najmanje: 5)), ["Istorija", "Sport"])
        XCTAssertEqual(spil.sledece(tema: "Sport")?.zanr, "Sport")
        XCTAssertEqual(spil.teme(najmanje: 6), ["Istorija"])
    }
}

/// Vlasnik 03.11: izabrana vojska je nestajala u partiji iz čekaonice (pomoći su uvek bile Graditelja).
final class VojskaIzSobeTests: XCTestCase {
    func testCovekIzSobeZadrzavaIzabranuVojsku() {
        var r = Slucajno(seme: 5)
        for v in VrstaVojske.allCases {
            let s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, igraci: [
                NoviIgrac(id: "u:ja", ime: "Ja", boja: 0x12907E, covek: true, tim: "A", vojska: v),
                NoviIgrac(id: "bot1", ime: "Mimi", boja: 0xFF5FA2, covek: false, tim: "B"),
            ])
            XCTAssertEqual(s.vojskaTima("A"), v)
            XCTAssertEqual(Set(v.pomoci).count, 3)
        }
        XCTAssertEqual(Set(VrstaVojske.allCases.flatMap(\.pomoci)).count, VrstaVojske.allCases.count * 3, "vlasnik 04.11: tri svoje moći po vojsci")
    }
}

/// Vlasnik 03.11: sa botovima je svaka partija bila ista. Seme partije menja narav, vojsku, početne države i poteze botova.
final class RaznolikostBotovaTests: XCTestCase {
    private func nova(_ seme: UInt32, tezina: Tezina = .normalno) -> Stanje {
        var s = Slucajno(seme: seme)
        return Stanje.nova(krugova: 12, tezina: tezina, slucajno: &s, igraci: [
            NoviIgrac(id: "ti", ime: "Ti", boja: 0x12907E, covek: true, tim: "A", vojska: .legija),
            NoviIgrac(id: "bot1", ime: "Mimi", boja: 0xFF5FA2, covek: false, tim: "B"),
            NoviIgrac(id: "bot2", ime: "Zig", boja: 0x6D4BC9, covek: false, tim: "C"),
        ], pocetak: ["A": "evr", "B": "afr", "C": "azi"])
    }

    func testRazlicitePartijeRazlicitiBotovi() {
        let partije = (1...200).map { nova(UInt32($0) * 7919) }
        let naravi = Set(partije.map { $0.narav("bot1") })
        let vojske = Set(partije.compactMap { $0.vojskaTima("B") })
        let pocetni = Set(partije.map { $0.oblastiIgraca("bot1").sorted().joined(separator: ",") })
        XCTAssertEqual(naravi.count, 3, "bot ima sve tri naravi kroz partije")
        XCTAssertEqual(vojske.count, 6, "bot dobija svih šest vojski kroz partije")
        XCTAssertGreaterThan(pocetni.count, 30, "početne države bota nisu uvek iste")
    }

    func testIstaPartijaIstiPotezNaSvakomTelefonu() {
        let a = nova(42), b = nova(42)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.seme, b.seme)
    }

    func testPotezBotaSeMenjaOdPartijeDoPartije() {
        for tezina in Tezina.allCases {
            var potezi: Set<String> = []
            for i in 1...60 {
                var s = nova(UInt32(i) * 104_729, tezina: tezina)
                s.naPotezu = 1; s.faza = .napad
                if let p = s.botSledeciNapad() { potezi.insert(p.odakle + ">" + p.kuda) }
            }
            XCTAssertGreaterThan(potezi.count, 10, "\(tezina): prvi napad bota nije uvek isti")
        }
    }
}

/// Vlasnik 03.11: partija se srušila dok je Bloop napadao. Cele partije samih botova kroz sva pravila
/// (karte, savezi, izdaje, ultimatumi, ulog, utvrđivanje) ne smeju da padnu ni da zaglave.
final class CelaPartijaBotovaTests: XCTestCase {
    func testStotinuPartijaDoKrajaBezPada() {
        for seme in 1...60 {
            for igraca in [2, 4, 6] {
                var r = Slucajno(seme: UInt32(seme) &* 2_654_435_761)
                let boje: [UInt32] = [0x12907E, 0xFF5FA2, 0x6D4BC9, 0xF4A33C, 0x6EC3F2, 0xE5385C]
                let igraci = (0..<igraca).map { NoviIgrac(id: "b\($0)", ime: ["Bloop", "Mimi", "Zig", "Lumi", "Sara", "Max"][$0], boja: boje[$0], covek: false, tim: "T\($0)") }
                var s = Stanje.nova(krugova: 8, tezina: .tesko, slucajno: &r, igraci: igraci)
                var koraka = 0
                while s.faza != .kraj {
                    koraka += 1
                    XCTAssertLessThan(koraka, 5_000, "partija \(seme)/\(igraca) zaglavljena u krugu \(s.krug)")
                    if koraka >= 5_000 { break }
                    s = s.snabdevanje(tacno: r.sledeci() < s.tacnostBota).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez()
                        .botIzdaja().botNajaviPohod().botUltimatum()
                    var napada = 0
                    while let n = s.botSledeciNapad(), napada < 40 {
                        napada += 1
                        if s.oblasti[n.kuda]?.vlasnik != nil {
                            s = s.postaviUlog(Stanje.ulogBota(0.8))
                            (s, _) = s.razresiBitkuSkorom(odakle: n.odakle, kuda: n.kuda, napadac: s.botSkor(&r), branilac: s.botSkor(&r))
                        } else {
                            (s, _) = s.razresiBitku(odakle: n.odakle, kuda: n.kuda, napadac: s.botOdgovor(&r), branilac: nil)
                        }
                        if s.faza == .kraj { break }
                    }
                    XCTAssertLessThan(napada, 40, "bot ne prestaje da napada (partija \(seme))")
                    if s.faza == .napad { s = s.botUtvrdi() }
                    if s.faza != .kraj { s = s.zavrsiPotez() }
                }
            }
        }
    }
}

/// Pad 03.11 (Bloop napadao dok je igrač branio): napad koji je u međuvremenu prestao da važi ne ruši aplikaciju.
final class NapadKojiNeVaziTests: XCTestCase {
    func testBitkaPosleIzmeneStanjaSePreskace() {
        var r = Slucajno(seme: 99)
        var s = Stanje.nova(krugova: 5, tezina: .normalno, slucajno: &r)
        s = s.snabdevanje(tacno: true)
        while s.faza == .raspored, let id = s.oblastiIgraca(s.trenutni.id).first { s = s.rasporedi(id) }
        guard let odakle = s.oblastiIgraca(s.trenutni.id).first(where: { !s.mete($0).isEmpty }), let kuda = s.mete(odakle).first else {
            return XCTFail("nema napada u probnoj partiji")
        }
        var promenjeno = s
        promenjeno.faza = .raspored // npr. potez je u međuvremenu prošao
        let (posle, ishod) = promenjeno.razresiBitkuSkorom(odakle: odakle, kuda: kuda, napadac: Skor(tacnih: 5, ms: 1), branilac: Skor(tacnih: 0, ms: 1))
        XCTAssertEqual(posle, promenjeno)
        XCTAssertFalse(ishod.osvojeno)
        let (posle2, _) = promenjeno.razresiBitku(odakle: odakle, kuda: kuda, napadac: Odgovor(tacan: true, ms: 1), branilac: nil)
        XCTAssertEqual(posle2, promenjeno)
    }
}

/// Otisak partije za isto seme mora biti isti na iOS-u i Androidu (PravilaTest.kt, OtisakPartijeTest): partija preko dva telefona.
final class OtisakPartijeTests: XCTestCase {
    static let ocekivano = "131503810|ti:PRK:mudraci,mimi:FRA:izvidnica,zig:AFG:graditelji|mimi=regiona6-kontinent,ti=drzava45x2,zig=evr-afr|ti=8/20,mimi=10/20,zig=9/10"

    func testIstaPartijaKaoAndroid() {
        var r = Slucajno(seme: 42)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, misije: true)
        for _ in 0..<6 {
            s = s.snabdevanje(tacno: true).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez().botIzdaja().botNajaviPohod().botUltimatum()
            var n = 0
            while n < 10, let a = s.botSledeciNapad() {
                n += 1
                s = s.oblasti[a.kuda]?.vlasnik != nil ? s.razresiBitkuSkorom(odakle: a.odakle, kuda: a.kuda, napadac: s.botSkor(&r), branilac: s.botSkor(&r)).0
                    : s.razresiBitku(odakle: a.odakle, kuda: a.kuda, napadac: s.botOdgovor(&r), branilac: nil).0
            }
            if s.faza == .napad { s = s.botUtvrdi() }
            s = s.zavrsiPotez()
        }
        let otisak = "\(s.seme ?? 0)|" + s.igraci.map { "\($0.id):\($0.prestonica):\($0.vojska?.rawValue ?? "")" }.joined(separator: ",") + "|"
            + s.misije.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",") + "|"
            + s.igraci.map { i in "\(i.tim)=\(s.oblastiIgraca(i.id).count)/\(s.oblastiIgraca(i.id).reduce(0) { $0 + (s.oblasti[$1]?.vojske ?? 0) })" }.joined(separator: ",")
        print("OTISAK", otisak)
        XCTAssertEqual(otisak, Self.ocekivano)
    }
}

/// Pad 03.11 u 9. krugu od 30 (šest igrača, Karneval): duge partije, timovi i sve strategije botova bez pada.
final class DugaPartijaBotovaTests: XCTestCase {
    func testTridesetKrugovaSestIgracaITimovi() {
        // 25 semena je provereno 03.11 (18 min); u svakoj gradnji idu 3.
        for seme in 1...3 {
            for (igraca, timovi) in [(5, false), (6, false), (6, true), (4, true)] {
                var r = Slucajno(seme: UInt32(seme) &* 40_503 &+ UInt32(igraca))
                let boje: [UInt32] = [0x12907E, 0xFF5FA2, 0x6D4BC9, 0xF4A33C, 0x6EC3F2, 0xE5385C]
                let igraci = (0..<igraca).map {
                    NoviIgrac(id: "b\($0)", ime: "B\($0)", boja: boje[$0], covek: false, tim: timovi ? "T\($0 / 2)" : "T\($0)", kapiten: !timovi || $0 % 2 == 0)
                }
                var s = Stanje.nova(krugova: 30, tezina: .tesko, slucajno: &r, igraci: igraci)
                var koraka = 0
                while s.faza != .kraj && koraka < 8_000 {
                    koraka += 1
                    s = s.snabdevanje(tacno: r.sledeci() < s.tacnostBota).botRasporedi().botOdbrana().botIgraKarte().botTraziSavez()
                        .botIzdaja().botNajaviPohod().botUltimatum()
                    var napada = 0
                    while let n = s.botSledeciNapad(), napada < 40 {
                        napada += 1
                        if s.oblasti[n.kuda]?.vlasnik != nil {
                            s = s.postaviUlog(Stanje.ulogBota(0.8))
                            (s, _) = s.razresiBitkuSkorom(odakle: n.odakle, kuda: n.kuda, napadac: s.botSkor(&r), branilac: s.botSkor(&r))
                        } else {
                            (s, _) = s.razresiBitku(odakle: n.odakle, kuda: n.kuda, napadac: s.botOdgovor(&r), branilac: nil)
                        }
                        if s.faza == .kraj { break }
                    }
                    if s.faza == .napad { s = s.botUtvrdi() }
                    if s.faza != .kraj { s = s.zavrsiPotez() }
                    XCTAssertTrue(s.oblasti.values.allSatisfy { $0.vojske >= 0 }, "negativne vojske, partija \(seme)/\(igraca)")
                }
                XCTAssertLessThan(koraka, 8_000, "partija \(seme)/\(igraca)/\(timovi) zaglavljena")
            }
        }
    }
}

/// Pravila od 04.11.2026: kontranapad, opsada prestonice, stalni savez i pomoć savezniku, savet, istorijski likovi.
final class Pravila0411Tests: XCTestCase {
    private func napad(_ vlasnici: [(String, String, Int)]) -> Stanje {
        var r = Slucajno(seme: 1)
        var s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r)
        s.faza = .napad
        for o in Mapa.oblasti { s.oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: 1) }
        for (id, v, n) in vlasnici { s.oblasti[id] = StanjeOblasti(vlasnik: v, vojske: n) }
        s.igraci = s.igraci.map { var i = $0; i.vojska = nil; return i }
        s.karteTimova = [:]
        return s
    }

    func testKontranapadPosleOdbraneSaTriTacna() {
        let s = napad([("ESP", "ti", 3), ("FRA", "mimi", 3)])
        let (posle, ishod) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 1, ms: 9), branilac: Skor(tacnih: 3, ms: 1))
        XCTAssertFalse(ishod.osvojeno)
        XCTAssertEqual(posle.kontranapad?["mimi"], "ESP")
        // Odbrana sa 2 tačna nema kontranapad.
        let (slabo, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 0, ms: 9), branilac: Skor(tacnih: 2, ms: 1))
        XCTAssertNil(slabo.kontranapad?["mimi"])
    }

    func testKontranapadDajeNapadVisePrednostINestaje() {
        var s = napad([("ESP", "mimi", 4), ("FRA", "ti", 3)])
        s.naPotezu = s.igraci.firstIndex { $0.id == "mimi" }!
        let bez = s.napadaPoPotezu
        let pomakBez = s.pomakBitke(odakle: "ESP", kuda: "FRA")
        s.kontranapad = ["mimi": "ESP"]
        XCTAssertEqual(s.napadaPoPotezu, bez + 1)
        XCTAssertEqual(s.pomakBitke(odakle: "ESP", kuda: "FRA"), pomakBez + 1)
        XCTAssertNil(s.zavrsiPotez().kontranapad?["mimi"])
    }

    func testOpsadaPrestoniceDajeKartuPosleDvaNapada() {
        var s = napad([("ESP", "ti", 3), ("FRA", "mimi", 6)])
        s.igraci = s.igraci.map { var i = $0; if i.id == "mimi" { i.prestonica = "FRA" }; return i }
        let (prvi, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 0, ms: 9), branilac: Skor(tacnih: 1, ms: 1))
        XCTAssertEqual(prvi.opsada?["FRA"], 1)
        var drugi = prvi
        drugi.oblasti["ESP"] = StanjeOblasti(vlasnik: "ti", vojske: 3)
        drugi.bitaka = 0
        let karata = drugi.karte("mimi").count
        let (posle, _) = drugi.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 0, ms: 9), branilac: Skor(tacnih: 0, ms: 1))
        XCTAssertEqual(posle.opsada?["FRA"], 0)
        // Pobeda u odbrani daje kartu i bez opsade, pa opsada daje još jednu.
        XCTAssertGreaterThanOrEqual(posle.karte("mimi").count, karata + 2)
    }

    private func uSavezu(_ s: Stanje) -> Stanje {
        var s = s
        s.savezi = [Stanje.kljucSaveza("ti", "mimi"): Stanje.savezDoKraja]
        return s
    }

    func testSavezDoKrajaJedanSaveznik() {
        let s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 2)]))
        XCTAssertTrue(s.uSavezu("ti", "mimi"))
        XCTAssertFalse(s.mete("ESP").contains("FRA"))
        // Treći ne može u savez sa nekim ko već ima saveznika.
        XCTAssertFalse(s.predloziSavez(od: "zig", za: "ti", prihvata: true).uSavezu("zig", "ti"))
    }

    func testIzdajaKaznaDvaKruga() {
        var s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 2)]))
        s.karteTimova = ["ti": [.spijun]]
        let posle = s.izdaj("ti", "mimi")
        XCTAssertFalse(posle.uSavezu("ti", "mimi"))
        XCTAssertTrue(posle.karte("ti").isEmpty)
        XCTAssertTrue(posle.podKaznom("ti"))
        XCTAssertEqual(posle.izdaje?["ti"], 1)
        var kasnije = posle; kasnije.krug += 2
        XCTAssertFalse(kasnije.podKaznom("ti"))
    }

    func testRaskidISledeciSaveznikPosleKruga() {
        let s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 2)]))
        let r = s.raskiniSavez("ti")!
        XCTAssertTrue(r.uSavezu("ti", "mimi"))
        var sledeci = r; sledeci.krug += 1
        XCTAssertFalse(sledeci.uSavezu("ti", "mimi"))
        XCTAssertFalse(sledeci.predloziSavez(od: "ti", za: "zig", prihvata: true).uSavezu("ti", "zig"))
        sledeci.krug += 1
        XCTAssertTrue(sledeci.predloziSavez(od: "ti", za: "zig", prihvata: true).uSavezu("ti", "zig"))
    }

    func testZamenaMisijaDoPetogKruga() {
        var s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 2)]))
        s.misije = ["ti": "drzava60", "mimi": "evr-afr", "zig": "azi-oke"]
        let z = s.predloziZamenuMisije(od: "ti", za: "mimi", prihvata: true)!
        XCTAssertEqual(z.misije["ti"], "evr-afr")
        XCTAssertEqual(z.misije["mimi"], "drzava60")
        s.krug = Pravila.zamenaMisijaDoKruga + 1
        XCTAssertNil(s.predloziZamenuMisije(od: "ti", za: "mimi", prihvata: true))
    }

    func testPomocSavezniku() {
        let s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 1)]))
        let posle = s.posaljiPomoc(od: "ti", za: "mimi")
        XCTAssertEqual(posle?.oblasti["ESP"]?.vojske, 3)
        XCTAssertEqual(posle?.oblasti["FRA"]?.vojske, 3)
        XCTAssertEqual(posle?.poslednjaPomoc?[1], "mimi")
        XCTAssertNil(posle?.posaljiPomoc(od: "ti", za: "mimi"))
        XCTAssertNil(napad([("ESP", "ti", 5), ("FRA", "mimi", 1)]).posaljiPomoc(od: "ti", za: "mimi"))
    }

    func testSavezPobedujeZajednoKadaOstaneSamoJednaStrana() {
        var s = uSavezu(napad([("ESP", "ti", 5), ("FRA", "mimi", 2)]))
        s.igraci = s.igraci.map { var i = $0; if i.id == "zig" { i.ispao = true }; return i }
        XCTAssertEqual(s.zavrsiPotez().faza, .kraj)
    }

    func testMisijaPobedjujeTekPosleKruga() {
        var s = napad([("ESP", "ti", 5)])
        s.misije = ["ti": "drzava60", "mimi": "evr-afr", "zig": "azi-oke"]
        for o in Mapa.oblasti.prefix(120) { s.oblasti[o.id] = StanjeOblasti(vlasnik: "ti", vojske: 2) }
        XCTAssertGreaterThanOrEqual(s.napredakMisije("ti"), 1)
        let prvi = s.zavrsiPotez()
        XCTAssertNil(prvi.pobednik)
        XCTAssertNotNil(prvi.misijaOd?["ti"])
        var dalje = prvi
        while dalje.trenutni.tim != "ti" && dalje.faza != .kraj { dalje = dalje.zavrsiPotez() }
        XCTAssertEqual(dalje.pobednik, "ti")
    }

    func testOsamnaestRazlicitihMoci() {
        let sve = VrstaVojske.allCases.flatMap(\.pomoci)
        XCTAssertEqual(sve.count, 18)
        XCTAssertEqual(Set(sve).count, 18)
        XCTAssertGreaterThanOrEqual(Misije.sve.count, 60)
        XCTAssertEqual(Set(Misije.sve.map(\.id)).count, Misije.sve.count)
    }

    func testMociMenjajuIshod() {
        let s = napad([("ESP", "ti", 3), ("FRA", "mimi", 2)])
        // Temelj: poraz ne odnosi državu napadača.
        let (t, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 0, ms: 9, efekti: ["temelj"]), branilac: Skor(tacnih: 4, ms: 1))
        XCTAssertEqual(t.oblasti["ESP"]?.vlasnik, "ti")
        // Garnizon: uspešna odbrana +2.
        let (g, _) = s.razresiBitkuSkorom(odakle: "ESP", kuda: "FRA", napadac: Skor(tacnih: 0, ms: 9), branilac: Skor(tacnih: 4, ms: 1, efekti: ["garnizon"]))
        XCTAssertEqual(g.oblasti["FRA"]?.vojske, 4)
    }

    func testSavetBiraNajboljiNapad() {
        let s = napad([("ESP", "ti", 6), ("FRA", "mimi", 1)])
        let n = s.najboljiNapad()
        XCTAssertNotNil(n)
        XCTAssertTrue(s.mete(n!.odakle).contains(n!.kuda))
    }
}

/// Vlasnik 04.11 kasno: sam / savez / zajedno i protiv računara, izbor na podešavanju.
final class SaveznikNaPodesavanjuTests: XCTestCase {
    private func postavka(_ n: Int) -> OsvajanjePostavka {
        OsvajanjePostavka(nacin: .svakoZaSebe, igraca: n, krugova: 12, tezina: .normalno, igraci: OsvajanjePostavka.mesta(.svakoZaSebe, n, ime: "Ti"))
    }

    func testSamOstajeSvakoZaSebe() {
        var p = postavka(4)
        OsvajanjeUvodView.primeniSaveznika(.bez, &p)
        XCTAssertEqual(Set(p.igraci.compactMap(\.tim)).count, 4)
        XCTAssertNil(p.igraci.first?.strana)
    }

    func testZajednoDeliTimSaJednimBotom() {
        var p = postavka(4)
        OsvajanjeUvodView.primeniSaveznika(.zajedno, &p)
        XCTAssertEqual(p.nacin, .timovi)
        XCTAssertEqual(p.igraci.filter { $0.tim == "A" }.count, 2)
        XCTAssertEqual(Set(p.igraci.compactMap(\.tim)), ["A", "B", "C"])
        XCTAssertTrue(p.igraci.first { $0.covek }!.kapiten)
    }

    func testSavezDajeSvakomSvojTimIStranu() {
        var p = postavka(4)
        OsvajanjeUvodView.primeniSaveznika(.savez, &p)
        XCTAssertEqual(p.nacin, .svakoZaSebe)
        XCTAssertEqual(Set(p.igraci.compactMap(\.tim)).count, 4)
        let ja = p.igraci.first { $0.covek }!
        XCTAssertEqual(p.igraci.filter { $0.strana == ja.strana }.count, 2)
        // Iz postavke nastaje stanje u kojem smo saveznici od prvog kruga.
        var r = Slucajno(seme: 7)
        let s = Stanje.nova(krugova: 12, tezina: .normalno, slucajno: &r, igraci: p.igraci)
        let saveznik = p.igraci.first { !$0.covek && $0.strana == ja.strana }!
        XCTAssertTrue(s.uSavezu(ja.tim!, saveznik.tim!))
    }
}
