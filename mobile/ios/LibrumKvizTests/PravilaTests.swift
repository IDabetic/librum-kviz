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
        XCTAssertEqual(zev.pojacanja("ti", tacno: true), 3 + bonus)
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
