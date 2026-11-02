import XCTest
@testable import LibrumKviz

/// Isti slučajevi kao tests/osvajanje.test.mjs na vebu.
final class PravilaTests: XCTestCase {
    private func nova(_ seme: UInt32 = 1) -> Stanje {
        var s = Slucajno(seme: seme)
        return Stanje.nova(krugova: 10, tezina: .normalno, slucajno: &s)
    }

    func testMapaPovezanaISimetricna() {
        XCTAssertEqual(Mapa.oblasti.count, 24)
        for o in Mapa.oblasti { for n in Mapa.susedi(o.id) { XCTAssertTrue(Mapa.susedi(n).contains(o.id)) } }
        var vidjeno: Set = ["aljaska"], red = ["aljaska"]
        while let x = red.popLast() { for n in Mapa.susedi(x) where vidjeno.insert(n).inserted { red.append(n) } }
        XCTAssertEqual(vidjeno.count, 24)
    }

    func testIstiGeneratorKaoVeb() {
        // mulberry32(1): prve tri vrednosti iz Node-a.
        var s = Slucajno(seme: 1)
        XCTAssertEqual(s.sledeci(), 0.6270739405881613, accuracy: 1e-12)
        XCTAssertEqual(s.sledeci(), 0.002735721180215478, accuracy: 1e-12)
        XCTAssertEqual(s.sledeci(), 0.5274470399599522, accuracy: 1e-12)
    }

    func testPrestoniceNaRazlicitimKontinentima() {
        let s = nova(3)
        XCTAssertEqual(Set(s.igraci.map { Mapa.oblast($0.prestonica).kontinent }).count, 3)
    }

    func testSnabdevanjeIRaspored() {
        let s = nova()
        XCTAssertEqual(s.snabdevanje(tacno: true).zaRaspored, 3)
        let r = s.snabdevanje(tacno: false)
        XCTAssertEqual(r.zaRaspored, 1)
        XCTAssertEqual(r.rasporedi(s.igraci[0].prestonica).faza, .napad)
    }

    func testOsvajanjeIProboj() {
        var s = nova().snabdevanje(tacno: true)
        let dom = s.igraci[0].prestonica
        while s.faza == .raspored { s = s.rasporedi(dom) }
        let meta = s.mete(dom)[0]
        let (novo, ishod) = s.razresiBitku(odakle: dom, kuda: meta, napadac: Odgovor(tacan: true, ms: 1), branilac: nil)
        XCTAssertTrue(ishod.osvojeno)
        XCTAssertEqual(novo.oblasti[meta]?.vlasnik, "ti")
        XCTAssertEqual(novo.oblasti[dom]?.vojske, 1)
        XCTAssertEqual(novo.oblasti[meta]?.vojske, 6)
        XCTAssertFalse(novo.mete(meta).isEmpty)
    }

    func testBitkaProtivIgraca() {
        var s = nova().snabdevanje(tacno: true)
        s.faza = .napad
        s.oblasti["balkan"] = StanjeOblasti(vlasnik: "ti", vojske: 5)
        s.oblasti["bliski-istok"] = StanjeOblasti(vlasnik: "mimi", vojske: 4)
        var r = s.razresiBitku(odakle: "balkan", kuda: "bliski-istok", napadac: .init(tacan: true, ms: 2000), branilac: .init(tacan: true, ms: 5000))
        XCTAssertEqual(r.0.oblasti["bliski-istok"]?.vojske, 3)
        r = s.razresiBitku(odakle: "balkan", kuda: "bliski-istok", napadac: .init(tacan: false, ms: 1), branilac: .init(tacan: false, ms: 1))
        XCTAssertEqual(r.0.oblasti["balkan"]?.vojske, 4)
        XCTAssertEqual(r.0.oblasti["bliski-istok"]?.vojske, 3)
        r = s.razresiBitku(odakle: "balkan", kuda: "bliski-istok", napadac: .init(tacan: false, ms: 1), branilac: .init(tacan: true, ms: 1))
        XCTAssertEqual(r.0.oblasti["balkan"]?.vojske, 3)
    }

    func testTreceOsvajanjeDonosiProboj() {
        var s = nova()
        s.faza = .napad
        s.oblasti["peru"] = StanjeOblasti(vlasnik: "ti", vojske: 10)
        var tren = "peru"
        var poslednji: Ishod?
        for _ in 0..<3 {
            let meta = s.mete(tren).first { s.oblasti[$0]?.vlasnik == nil }!
            let r = s.razresiBitku(odakle: tren, kuda: meta, napadac: .init(tacan: true, ms: 1), branilac: nil)
            s = r.0; tren = meta; poslednji = r.1
        }
        XCTAssertEqual(poslednji?.proboj, true)
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
