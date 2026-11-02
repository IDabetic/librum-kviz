import Foundation

// Verni prevod src/lib/osvajanje/pravila.ts. Kad se pravila menjaju, menjaju se
// na vebu, ovde i u Pravila.kt, zajedno sa testovima na sva tri mesta.

struct Kontinent { let id: String; let ime: String; let bonus: Int }
struct Oblast { let id: String; let ime: String; let kontinent: String; let x: Double; let y: Double }

enum Mapa {
    static let kontinenti: [Kontinent] = [
        .init(id: "sam", ime: "Severna Amerika", bonus: 3),
        .init(id: "jam", ime: "Južna Amerika", bonus: 2),
        .init(id: "evr", ime: "Evropa", bonus: 3),
        .init(id: "afr", ime: "Afrika", bonus: 3),
        .init(id: "azi", ime: "Azija", bonus: 4),
        .init(id: "oke", ime: "Okeanija", bonus: 2),
    ]

    static let oblasti: [Oblast] = [
        .init(id: "aljaska", ime: "Aljaska", kontinent: "sam", x: 80, y: 90),
        .init(id: "kanada", ime: "Kanada", kontinent: "sam", x: 190, y: 80),
        .init(id: "sad", ime: "SAD", kontinent: "sam", x: 200, y: 190),
        .init(id: "meksiko", ime: "Meksiko", kontinent: "sam", x: 180, y: 295),
        .init(id: "kolumbija", ime: "Kolumbija", kontinent: "jam", x: 270, y: 360),
        .init(id: "peru", ime: "Peru", kontinent: "jam", x: 250, y: 465),
        .init(id: "brazil", ime: "Brazil", kontinent: "jam", x: 360, y: 430),
        .init(id: "argentina", ime: "Argentina", kontinent: "jam", x: 330, y: 530),
        .init(id: "skandinavija", ime: "Skandinavija", kontinent: "evr", x: 480, y: 70),
        .init(id: "zap-evropa", ime: "Zapadna Evropa", kontinent: "evr", x: 430, y: 175),
        .init(id: "sre-evropa", ime: "Srednja Evropa", kontinent: "evr", x: 535, y: 165),
        .init(id: "balkan", ime: "Balkan", kontinent: "evr", x: 575, y: 260),
        .init(id: "sev-afrika", ime: "Severna Afrika", kontinent: "afr", x: 475, y: 310),
        .init(id: "zap-afrika", ime: "Zapadna Afrika", kontinent: "afr", x: 440, y: 415),
        .init(id: "ist-afrika", ime: "Istočna Afrika", kontinent: "afr", x: 570, y: 400),
        .init(id: "juz-afrika", ime: "Južna Afrika", kontinent: "afr", x: 520, y: 505),
        .init(id: "sibir", ime: "Sibir", kontinent: "azi", x: 720, y: 85),
        .init(id: "bliski-istok", ime: "Bliski istok", kontinent: "azi", x: 670, y: 285),
        .init(id: "indija", ime: "Indija", kontinent: "azi", x: 770, y: 335),
        .init(id: "kina", ime: "Kina", kontinent: "azi", x: 810, y: 210),
        .init(id: "japan", ime: "Japan", kontinent: "azi", x: 925, y: 150),
        .init(id: "indonezija", ime: "Indonezija", kontinent: "oke", x: 870, y: 400),
        .init(id: "australija", ime: "Australija", kontinent: "oke", x: 920, y: 505),
        .init(id: "novi-zeland", ime: "Novi Zeland", kontinent: "oke", x: 1000, y: 430),
    ]

    static let veze: [(String, String)] = [
        ("aljaska", "kanada"), ("aljaska", "sibir"), ("aljaska", "sad"), ("kanada", "sad"), ("kanada", "skandinavija"),
        ("sad", "meksiko"), ("meksiko", "kolumbija"),
        ("kolumbija", "peru"), ("kolumbija", "brazil"), ("peru", "brazil"), ("peru", "argentina"), ("brazil", "argentina"),
        ("brazil", "zap-afrika"),
        ("skandinavija", "zap-evropa"), ("skandinavija", "sre-evropa"), ("skandinavija", "sibir"),
        ("zap-evropa", "sre-evropa"), ("zap-evropa", "sev-afrika"), ("sre-evropa", "balkan"), ("sre-evropa", "sibir"),
        ("balkan", "bliski-istok"), ("balkan", "sev-afrika"),
        ("sev-afrika", "zap-afrika"), ("sev-afrika", "ist-afrika"), ("sev-afrika", "bliski-istok"),
        ("zap-afrika", "ist-afrika"), ("zap-afrika", "juz-afrika"), ("ist-afrika", "juz-afrika"), ("ist-afrika", "bliski-istok"),
        ("bliski-istok", "indija"), ("bliski-istok", "sibir"), ("sibir", "kina"), ("sibir", "japan"),
        ("kina", "indija"), ("kina", "japan"), ("kina", "indonezija"), ("indija", "indonezija"),
        ("indonezija", "australija"), ("australija", "novi-zeland"), ("indonezija", "novi-zeland"),
    ]

    private static let susedstvo: [String: [String]] = {
        var s: [String: [String]] = [:]
        for (a, b) in veze { s[a, default: []].append(b); s[b, default: []].append(a) }
        return s
    }()

    static func susedi(_ id: String) -> [String] { susedstvo[id] ?? [] }
    static func oblast(_ id: String) -> Oblast { oblasti.first { $0.id == id }! }
}

enum Pravila {
    static let pocetneVojskePrestonice = 4
    static let neutralneVojske = 1
    static let najmanjePojacanja = 3
    static let bitakaPoPotezu = 6
    static let probojSvakih = 3
    static let probojBonus = 2
    static let plenPrestonice = 5
    static let poeniPoOblasti = 10
    static let poeniPoBonusu = 10
    static let poeniPrestonica = 20
    static let sekundiPoPitanju = 15
}

enum Tezina: String, CaseIterable, Identifiable {
    case lako, normalno, tesko
    var id: String { rawValue }
    var tacnost: Double { switch self { case .lako: 0.5; case .normalno: 0.62; case .tesko: 0.75 } }
    var ime: String { switch self { case .lako: "Lako"; case .normalno: "Normalno"; case .tesko: "Teško" } }
    var opis: String {
        switch self {
        case .lako: "Rivali greše svako drugo pitanje"
        case .normalno: "Rivali znaju oko 6 od 10"
        case .tesko: "Rivali znaju 3 od 4"
        }
    }
}

struct Igrac: Equatable {
    let id: String
    var ime: String
    let boja: UInt32
    let covek: Bool
    let prestonica: String
    var ispao: Bool
}

struct StanjeOblasti: Equatable { var vlasnik: String?; var vojske: Int }

enum Faza: Equatable { case snabdevanje, raspored, napad, kraj }

struct Odgovor: Equatable { let tacan: Bool; let ms: Int }

struct Ishod: Equatable {
    let gubitakNapadaca: Int
    let gubitakBranioca: Int
    let osvojeno: Bool
    let proboj: Bool
    let plen: Bool
}

/// Deterministički generator (mulberry32), isti kao na vebu.
struct Slucajno {
    private var a: UInt32
    init(seme: UInt32) { a = seme }
    mutating func sledeci() -> Double {
        a = a &+ 0x6D2B79F5
        var t = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4294967296
    }
}

struct Stanje: Equatable {
    var igraci: [Igrac]
    var oblasti: [String: StanjeOblasti]
    var krug: Int
    var ukupnoKrugova: Int
    var naPotezu: Int
    var faza: Faza
    var zaRaspored: Int
    var bitaka: Int
    var niz: Int
    var utvrdjeno: Bool
    var tacnostBota: Double

    var trenutni: Igrac { igraci[naPotezu] }

    /// Nova partija: prestonice na različitim kontinentima, ostalo neutralno.
    static func nova(krugova: Int, tezina: Tezina, slucajno: inout Slucajno, ime: String? = nil) -> Stanje {
        var kontinenti = Mapa.kontinenti
        for i in stride(from: kontinenti.count - 1, to: 0, by: -1) {
            let j = Int(slucajno.sledeci() * Double(i + 1))
            kontinenti.swapAt(i, j)
        }
        let osnova: [(String, String, UInt32, Bool)] = [
            ("ti", "Ti", 0x12907E, true), ("mimi", "Mimi", 0xFF5FA2, false), ("zig", "Zig", 0x6D4BC9, false),
        ]
        var igraci: [Igrac] = []
        for (i, p) in osnova.enumerated() {
            let kandidati = Mapa.oblasti.filter { $0.kontinent == kontinenti[i].id }
            let prestonica = kandidati[Int(slucajno.sledeci() * Double(kandidati.count))].id
            igraci.append(Igrac(id: p.0, ime: p.3 ? (ime ?? p.1) : p.1, boja: p.2, covek: p.3, prestonica: prestonica, ispao: false))
        }
        var oblasti: [String: StanjeOblasti] = [:]
        for o in Mapa.oblasti { oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: Pravila.neutralneVojske) }
        for p in igraci { oblasti[p.prestonica] = StanjeOblasti(vlasnik: p.id, vojske: Pravila.pocetneVojskePrestonice) }
        return Stanje(igraci: igraci, oblasti: oblasti, krug: 1, ukupnoKrugova: krugova, naPotezu: 0, faza: .snabdevanje,
                      zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false, tacnostBota: tezina.tacnost)
    }

    func oblastiIgraca(_ id: String) -> [String] {
        Mapa.oblasti.filter { oblasti[$0.id]?.vlasnik == id }.map(\.id)
    }

    func bonusKontinenata(_ id: String) -> Int {
        Mapa.kontinenti
            .filter { k in Mapa.oblasti.filter { $0.kontinent == k.id }.allSatisfy { oblasti[$0.id]?.vlasnik == id } }
            .reduce(0) { $0 + $1.bonus }
    }

    func pojacanja(_ id: String, tacno: Bool) -> Int {
        let puno = max(Pravila.najmanjePojacanja, oblastiIgraca(id).count / 2) + bonusKontinenata(id)
        return tacno ? puno : max(1, puno / 2)
    }

    func snabdevanje(tacno: Bool) -> Stanje {
        guard faza == .snabdevanje else { return self }
        var s = self
        s.faza = .raspored
        s.zaRaspored = pojacanja(trenutni.id, tacno: tacno)
        return s
    }

    func rasporedi(_ oblastId: String) -> Stanje {
        guard faza == .raspored, zaRaspored > 0, oblasti[oblastId]?.vlasnik == trenutni.id else { return self }
        var s = self
        s.oblasti[oblastId]!.vojske += 1
        s.zaRaspored -= 1
        if s.zaRaspored == 0 { s.faza = .napad }
        return s
    }

    func mete(_ odakle: String) -> [String] {
        guard faza == .napad, bitaka < Pravila.bitakaPoPotezu,
              let izvor = oblasti[odakle], izvor.vlasnik == trenutni.id, izvor.vojske >= 2 else { return [] }
        return Mapa.susedi(odakle).filter { oblasti[$0]?.vlasnik != izvor.vlasnik }
    }

    var mozeDaNapada: Bool { oblastiIgraca(trenutni.id).contains { !mete($0).isEmpty } }

    /// Razrešava bitku. `branilac` je nil kad je oblast neutralna.
    func razresiBitku(odakle: String, kuda: String, napadac: Odgovor, branilac: Odgovor?) -> (Stanje, Ishod) {
        precondition(mete(odakle).contains(kuda), "Napad \(odakle) → \(kuda) nije dozvoljen")
        let izvor = oblasti[odakle]!
        let meta = oblasti[kuda]!

        var gubitakNapadaca = 0
        var gubitakBranioca = 0
        if meta.vlasnik == nil || branilac == nil {
            if napadac.tacan { gubitakBranioca = 1 } else { gubitakNapadaca = 1 }
        } else if let b = branilac {
            switch (napadac.tacan, b.tacan) {
            case (true, false): gubitakBranioca = 2
            case (false, true): gubitakNapadaca = 2
            // Nerešen odgovor rešava brzina; jednako vreme ide braniocu.
            case (true, true): if napadac.ms < b.ms { gubitakBranioca = 1 } else { gubitakNapadaca = 1 }
            case (false, false): gubitakNapadaca = 1; gubitakBranioca = 1
            }
        }

        let vojskeNapadaca = max(1, izvor.vojske - gubitakNapadaca)
        let vojskeBranioca = max(0, meta.vojske - gubitakBranioca)
        var s = self
        let osvojeno = vojskeBranioca == 0
        var proboj = false
        var plen = false

        if osvojeno {
            let prelazi = vojskeNapadaca - 1
            s.niz += 1
            proboj = s.niz % Pravila.probojSvakih == 0
            plen = meta.vlasnik != nil && igraci.contains { $0.prestonica == kuda && $0.id == meta.vlasnik }
            s.oblasti[odakle] = StanjeOblasti(vlasnik: izvor.vlasnik, vojske: 1)
            s.oblasti[kuda] = StanjeOblasti(
                vlasnik: izvor.vlasnik,
                vojske: max(1, prelazi) + (proboj ? Pravila.probojBonus : 0) + (plen ? Pravila.plenPrestonice : 0))
        } else {
            s.oblasti[odakle]!.vojske = vojskeNapadaca
            s.oblasti[kuda]!.vojske = vojskeBranioca
        }

        for i in s.igraci.indices where !s.igraci[i].ispao && s.oblastiIgraca(s.igraci[i].id).isEmpty {
            s.igraci[i].ispao = true
        }
        s.bitaka += 1
        let ishod = Ishod(gubitakNapadaca: izvor.vojske - vojskeNapadaca, gubitakBranioca: meta.vojske - vojskeBranioca,
                          osvojeno: osvojeno, proboj: proboj, plen: plen)
        return (s, ishod)
    }

    /// Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1.
    func utvrdi(odakle: String, kuda: String, broj: Int) -> Stanje {
        let id = trenutni.id
        guard faza == .napad, !utvrdjeno, let a = oblasti[odakle], let b = oblasti[kuda],
              a.vlasnik == id, b.vlasnik == id, Mapa.susedi(odakle).contains(kuda) else { return self }
        let n = min(broj, a.vojske - 1)
        guard n > 0 else { return self }
        var s = self
        s.utvrdjeno = true
        s.oblasti[odakle]!.vojske -= n
        s.oblasti[kuda]!.vojske += n
        return s
    }

    func zavrsiPotez() -> Stanje {
        guard faza != .kraj else { return self }
        var s = self
        if igraci.filter({ !$0.ispao }).count <= 1 { s.faza = .kraj; return s }
        var sledeci = naPotezu
        var krug = self.krug
        repeat {
            sledeci = (sledeci + 1) % igraci.count
            if sledeci == 0 { krug += 1 }
        } while igraci[sledeci].ispao
        if krug > ukupnoKrugova { s.faza = .kraj; return s }
        s.naPotezu = sledeci; s.krug = krug; s.faza = .snabdevanje
        s.zaRaspored = 0; s.bitaka = 0; s.niz = 0; s.utvrdjeno = false
        return s
    }

    func poeni(_ id: String) -> Int {
        let moje = oblastiIgraca(id)
        let vojske = moje.reduce(0) { $0 + (oblasti[$1]?.vojske ?? 0) }
        let prestonica = igraci.first { $0.id == id }.map { oblasti[$0.prestonica]?.vlasnik == id ? Pravila.poeniPrestonica : 0 } ?? 0
        return moje.count * Pravila.poeniPoOblasti + vojske + bonusKontinenata(id) * Pravila.poeniPoBonusu + prestonica
    }

    var poredak: [(igrac: Igrac, poeni: Int)] {
        igraci.map { ($0, poeni($0.id)) }.sorted { $0.1 > $1.1 }
    }

    // MARK: Botovi

    func botOdgovor(_ slucajno: inout Slucajno) -> Odgovor {
        Odgovor(tacan: slucajno.sledeci() < tacnostBota, ms: 3000 + Int(slucajno.sledeci() * 9000))
    }

    func botRasporedi() -> Stanje {
        var s = self
        while s.faza == .raspored {
            let id = s.trenutni.id
            let moje = s.oblastiIgraca(id)
            func pretnja(_ o: String) -> Int { Mapa.susedi(o).filter { s.oblasti[$0]?.vlasnik != id }.count }
            let cilj = moje.reduce(moje[0]) { pretnja($1) > pretnja($0) ? $1 : $0 }
            s = s.rasporedi(cilj)
        }
        return s
    }

    func botSledeciNapad() -> (odakle: String, kuda: String)? {
        let id = trenutni.id
        var najbolji: (String, String, Int)?
        for odakle in oblastiIgraca(id) {
            for kuda in mete(odakle) {
                let prednost = oblasti[odakle]!.vojske - oblasti[kuda]!.vojske
                if prednost < 1 { continue }
                let kont = Mapa.oblast(kuda).kontinent
                let fali = Mapa.oblasti.filter { $0.kontinent == kont && oblasti[$0.id]?.vlasnik != id }.count
                let ocena = prednost * 2 + (oblasti[kuda]!.vlasnik == nil ? 3 : 0) + (fali == 1 ? 5 : 0)
                if najbolji == nil || ocena > najbolji!.2 { najbolji = (odakle, kuda, ocena) }
            }
        }
        return najbolji.map { ($0.0, $0.1) }
    }
}
