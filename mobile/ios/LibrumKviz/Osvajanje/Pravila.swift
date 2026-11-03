import Foundation

// Verni prevod src/lib/osvajanje/pravila.ts. Kad se pravila menjaju, menjaju se
// na vebu, ovde i u Pravila.kt, zajedno sa testovima na sva tri mesta.

struct Region: Decodable { let id: String; let ime: String; let bonus: Int }

/// Država sa tačkom za natpis i SVG putanjom (M/L/Z) u koordinatama mape.
struct Oblast: Decodable { let id: String; let ime: String; let region: String; let x: Double; let y: Double; let boja: Int; let povrsina: Double; let d: String }

/// Mapa država iz svet.json (isti fajl kao veb i Android, pravi ga alati/napravi-mapu.mjs).
enum Mapa {
    private struct Svet: Decodable { let sirina: Double; let visina: Double; let regioni: [Region]; let drzave: [Oblast]; let veze: [[String]]; let more: [[Morski]] }

    /// Element morskog puta u JSON-u: ili oznaka države ili koordinata.
    enum Morski: Decodable {
        case id(String), broj(Double)
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let s = try? c.decode(String.self) { self = .id(s) } else { self = .broj(try c.decode(Double.self)) }
        }
        var tekst: String { if case let .id(s) = self { return s }; return "" }
        var vrednost: Double { if case let .broj(v) = self { return v }; return 0 }
    }

    private static let svet: Svet = {
        let url = Bundle(for: Oznacivac.self).url(forResource: "svet", withExtension: "json") ?? Bundle.main.url(forResource: "svet", withExtension: "json")!
        return try! JSONDecoder().decode(Svet.self, from: Data(contentsOf: url))
    }()
    private final class Oznacivac {}

    static var sirina: Double { svet.sirina }
    static var visina: Double { svet.visina }
    static var regioni: [Region] { svet.regioni }
    static var oblasti: [Oblast] { svet.drzave }
    static var veze: [(String, String)] { svet.veze.map { ($0[0], $0[1]) } }
    /// Morski putevi sa tačkama obala (a, b, od, do), za isprekidanu liniju.
    static let more: [(a: String, b: String, od: CGPoint, do: CGPoint)] = svet.more.map {
        ($0[0].tekst, $0[1].tekst, CGPoint(x: $0[2].vrednost, y: $0[3].vrednost), CGPoint(x: $0[4].vrednost, y: $0[5].vrednost))
    }

    private static let susedstvo: [String: [String]] = {
        var s: [String: [String]] = [:]
        for v in svet.veze { s[v[0], default: []].append(v[1]); s[v[1], default: []].append(v[0]) }
        return s
    }()
    private static let poId: [String: Oblast] = Dictionary(uniqueKeysWithValues: svet.drzave.map { ($0.id, $0) })

    static func susedi(_ id: String) -> [String] { susedstvo[id] ?? [] }
    static func oblast(_ id: String) -> Oblast { poId[id]! }
}

enum Pravila {
    static let pocetneVojskePrestonice = 5
    static let pocetnihDrzava = 6
    static let pocetneVojskeDrzave = 2
    /// Vreme za odluku na potezu; svaki dodir ga produžava.
    static let rokPotezaSekundi = 30
    /// Tri poteza zaredom bez napada (isteklo vreme) = igrač nije u igri i ispada.
    static let propustenihDoIspadanja = 3
    /// Vojske koje igrač sam raspoređuje na početne države pre prvog kruga (isto koliko dobija i automatski).
    static var vojskiNaPocetku: Int { pocetneVojskePrestonice + (pocetnihDrzava - 1) * pocetneVojskeDrzave }
    static let neutralneVojske = 1
    static let najmanjePojacanja = 3
    static let teritorijaPoVojsci = 2
    /// Napada zaredom po potezu kad svako igra za sebe; u timu po igraču (tim = 2 × 2).
    static let bitakaPoPotezu = 5
    static let bitakaUTimuPoIgracu = 2
    /// Bitka za državu koju drži igrač: niz pitanja, odlučuju tačni pa brzina.
    static let pitanjaUBitci = 5
    static let bonusPomociPobedniku = 2
    static let gubitakPorazenogNapadaca = 2
    static let probojSvakih = 3
    static let probojBonus = 2
    static let plenPrestonice = 5
    static let poeniPoOblasti = 10
    static let poeniPoBonusu = 10
    static let poeniPrestonica = 20
    static let sekundiPoPitanju = 15
    static let sekundiBrzSat = 8
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

struct Igrac: Equatable, Codable {
    let id: String
    var ime: String
    let boja: UInt32
    /// Igrač na ovom uređaju (u partiji preko servera svaki telefon postavlja svoje).
    var covek: Bool
    var prestonica: String
    var ispao: Bool
    /// Tim (vlasnik država). Svako za sebe: tim = id igrača.
    var tim: String
    /// Kapiten bira odbranu kontinenta (u timu član sa više tačnih na profilu).
    var kapiten: Bool = true
}

/// Igrač za novu partiju (čekaonica): bez prestonice, ona se bira na početku.
struct NoviIgrac { let id: String; let ime: String; let boja: UInt32; let covek: Bool; var tim: String? = nil; var kapiten = true }

struct StanjeOblasti: Equatable, Codable { var vlasnik: String?; var vojske: Int }

enum Faza: String, Equatable, Codable { case snabdevanje, raspored, napad, kraj }

struct Odgovor: Equatable { let tacan: Bool; let ms: Int }

/// Rezultat jedne strane u bitki od 5 pitanja.
struct Skor: Equatable, Codable { let tacnih: Int; let ms: Int }

struct Ishod: Equatable {
    let gubitakNapadaca: Int
    let gubitakBranioca: Int
    let osvojeno: Bool
    let proboj: Bool
    let plen: Bool
    /// Napadač je izgubio bitku protiv igrača, pa branilac uzima državu iz koje je napadnut.
    var izgubljenaDrzava = false
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

// MARK: Kontinenti, odbrane, misije (v3, docs/OSVAJANJE-VISE-IGRACA.md)

struct Kontinent: Equatable { let id: String; let ime: String; let regioni: [String] }

enum Kontinenti {
    static let svi: [Kontinent] = [
        Kontinent(id: "sam", ime: "Severna Amerika", regioni: ["sam", "kar"]),
        Kontinent(id: "jam", ime: "Južna Amerika", regioni: ["jam"]),
        Kontinent(id: "evr", ime: "Evropa", regioni: ["sev", "zev", "jev", "iev"]),
        Kontinent(id: "afr", ime: "Afrika", regioni: ["saf", "zaf", "caf", "iaf", "jaf"]),
        Kontinent(id: "azi", ime: "Azija", regioni: ["bli", "caz", "iaz", "jia"]),
        Kontinent(id: "oke", ime: "Okeanija", regioni: ["oke"]),
    ]
    static func od(_ oblastId: String) -> Kontinent { let r = Mapa.oblast(oblastId).region; return svi.first { $0.regioni.contains(r) }! }
    static func oblasti(_ id: String) -> [String] {
        guard let k = svi.first(where: { $0.id == id }) else { return [] }
        return Mapa.oblasti.filter { k.regioni.contains($0.region) }.map(\.id)
    }
}

enum Odbrana: String, CaseIterable, Identifiable, Codable {
    case brzSat, bezPomoci, teskoPitanje, prednost, temaBranioca, tvrdjava, zamka
    var id: String { rawValue }
    var naziv: String {
        switch self {
        case .brzSat: "Brz sat"; case .bezPomoci: "Bez pomoći"; case .teskoPitanje: "Teško pitanje"; case .prednost: "Prednost"
        case .temaBranioca: "Tema branioca"; case .tvrdjava: "Tvrđava"; case .zamka: "Zamka"
        }
    }
    var opis: String {
        switch self {
        case .brzSat: "Napadač ima 8 sekundi umesto 15."
        case .bezPomoci: "Napadač ne sme da koristi pomoć na ovom kontinentu."
        case .teskoPitanje: "Napadač dobija samo teška pitanja."
        case .prednost: "Napadaču trebaju bar 2 tačna više od branioca da osvoji."
        case .temaBranioca: "Pitanja za napadača su iz teme koju je branilac izabrao."
        case .tvrdjava: "Prvi poraz branioca u krugu se ne računa."
        case .zamka: "Kad napadač pogreši, gubi 2 vojske umesto 1."
        }
    }
    var cena: Int { switch self { case .teskoPitanje, .zamka: 1; case .prednost, .tvrdjava: 2; default: 0 } }
    var ikonica: String {
        switch self {
        case .brzSat: "timer"; case .bezPomoci: "nosign"; case .teskoPitanje: "brain"; case .prednost: "plus.forwardslash.minus"
        case .temaBranioca: "book"; case .tvrdjava: "shield.lefthalf.filled"; case .zamka: "exclamationmark.triangle"
        }
    }
}

struct Misija: Equatable { let id: String; let tekst: String; var samoPojedinacno = false }

enum Misije {
    static let sve: [Misija] = [
        Misija(id: "evr-jam", tekst: "Osvoji Evropu i Južnu Ameriku."),
        Misija(id: "evr-oke-jos", tekst: "Osvoji Evropu i Okeaniju, plus još jedan kontinent po izboru."),
        Misija(id: "sam-jam", tekst: "Osvoji Severnu i Južnu Ameriku."),
        Misija(id: "azi-jam", tekst: "Osvoji Aziju i Južnu Ameriku."),
        Misija(id: "afr-oke", tekst: "Osvoji Afriku i Okeaniju."),
        Misija(id: "sam-oke", tekst: "Osvoji Severnu Ameriku i Okeaniju."),
        Misija(id: "drzava60", tekst: "Drži 60 država."),
        Misija(id: "drzava45x2", tekst: "Drži 45 država sa najmanje 2 vojske u svakoj."),
        Misija(id: "regiona8", tekst: "Drži 8 celih regiona (region je grupa država, npr. ceo Balkan)."),
        Misija(id: "prestonice2", tekst: "Zauzmi prestonice dva rivala."),
        Misija(id: "izbaci", tekst: "Izbaci određenog rivala iz igre.", samoPojedinacno: true),
        Misija(id: "tacnih25", tekst: "Odgovori tačno na 25 pitanja i drži bar 30 država."),
    ]
    static func tekst(_ id: String?) -> String { sve.first { $0.id == id }?.tekst ?? "" }
}

struct Stanje: Equatable, Codable {
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
    var misije: [String: String] = [:]
    var metaMisije: [String: String] = [:]
    var odbrane: [String: Odbrana] = [:]
    var promenaOdbrane: [String: Int] = [:]
    var tvrdjava: [String: Int] = [:]
    var tacnih: [String: Int] = [:]
    var pobednik: String?
    var bonusPomoci: [String: Int] = [:]
    /// Potezi zaredom bez napada (isteklo vreme); na treći igrač ispada. Opciono, da stara stanja sa servera i dalje čitaju.
    var propusteno: [String: Int]?

    var trenutni: Igrac { igraci[naPotezu] }

    static let podrazumevani: [NoviIgrac] = [
        NoviIgrac(id: "ti", ime: "Ti", boja: 0x12907E, covek: true),
        NoviIgrac(id: "mimi", ime: "Mimi", boja: 0xFF5FA2, covek: false),
        NoviIgrac(id: "zig", ime: "Zig", boja: 0x6D4BC9, covek: false),
    ]

    /// Nova partija: prestonica na izabranom kontinentu (ili u regionu koji niko nema),
    /// po šest država oko nje, ostalo neutralno; po želji tajne misije.
    /// `teren` = id kontinenta: igra se samo na njemu (1 na 1 ili protiv računara), države van njega ne postoje.
    static func nova(krugova: Int, tezina: Tezina, slucajno: inout Slucajno, ime: String? = nil,
                     igraci spisak: [NoviIgrac]? = nil, pocetak: [String: String] = [:], misije: Bool = false, teren: String? = nil) -> Stanje {
        var regioni = Mapa.regioni
        for i in stride(from: regioni.count - 1, to: 0, by: -1) {
            let j = Int(slucajno.sledeci() * Double(i + 1))
            regioni.swapAt(i, j)
        }
        var oblasti: [String: StanjeOblasti] = [:]
        let naTerenu = teren.map { Set(Kontinenti.oblasti($0)) }
        for o in Mapa.oblasti where naTerenu?.contains(o.id) ?? true { oblasti[o.id] = StanjeOblasti(vlasnik: nil, vojske: Pravila.neutralneVojske) }
        var igraci: [Igrac] = []
        for p in spisak ?? podrazumevani {
            let tim = p.tim ?? p.id
            func slobodna(_ o: Oblast) -> Bool { Mapa.susedi(o.id).filter { oblasti[$0] != nil }.count >= 3 && oblasti[o.id] != nil && oblasti[o.id]?.vlasnik == nil }
            var lista: [Oblast]
            if let k = teren ?? pocetak[tim] {
                lista = Mapa.oblasti.filter { Kontinenti.od($0.id).id == k && slobodna($0) }
            } else if let region = regioni.first(where: { r in !igraci.contains { Mapa.oblast($0.prestonica).region == r.id } && Mapa.oblasti.contains { $0.region == r.id && slobodna($0) } }) {
                lista = Mapa.oblasti.filter { $0.region == region.id && slobodna($0) }
            } else {
                lista = []
            }
            if lista.isEmpty { lista = Mapa.oblasti.filter { oblasti[$0.id] != nil && oblasti[$0.id]?.vlasnik == nil } }
            let prestonica = lista[Int(slucajno.sledeci() * Double(lista.count))].id
            igraci.append(Igrac(id: p.id, ime: p.covek && spisak == nil ? (ime ?? p.ime) : p.ime, boja: p.boja, covek: p.covek,
                                prestonica: prestonica, ispao: false, tim: tim, kapiten: p.kapiten))
            // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
            var posed = [prestonica]
            var red = [prestonica]
            var vidjeno: Set = [prestonica]
            while !red.isEmpty && posed.count < Pravila.pocetnihDrzava {
                for n in Mapa.susedi(red.removeFirst()) where !vidjeno.contains(n) {
                    vidjeno.insert(n)
                    red.append(n)
                    if oblasti[n] != nil && oblasti[n]?.vlasnik == nil && posed.count < Pravila.pocetnihDrzava { posed.append(n) }
                }
            }
            for id in posed {
                oblasti[id] = StanjeOblasti(vlasnik: tim, vojske: id == prestonica ? Pravila.pocetneVojskePrestonice : Pravila.pocetneVojskeDrzave)
            }
        }
        var s = Stanje(igraci: igraci, oblasti: oblasti, krug: 1, ukupnoKrugova: krugova, naPotezu: 0, faza: .snabdevanje,
                       zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false, tacnostBota: tezina.tacnost)
        if misije { s.dodeliMisije(&slucajno) }
        return s
    }

    /// Tim igrača (vlasnik država); prima i id igrača i id tima.
    func timOd(_ id: String) -> String { igraci.first { $0.id == id }?.tim ?? id }

    /// Države igrača, tj. njegovog tima.
    func oblastiIgraca(_ id: String) -> [String] {
        let tim = timOd(id)
        return Mapa.oblasti.filter { oblasti[$0.id]?.vlasnik == tim }.map(\.id)
    }

    func bonusRegiona(_ id: String) -> Int {
        let tim = timOd(id)
        return Mapa.regioni
            .filter { r in Mapa.oblasti.filter { $0.region == r.id }.allSatisfy { oblasti[$0.id]?.vlasnik == tim } }
            .reduce(0) { $0 + $1.bonus }
    }

    func pojacanja(_ id: String, tacno: Bool) -> Int {
        let puno = max(Pravila.najmanjePojacanja, oblastiIgraca(id).count / Pravila.teritorijaPoVojsci) + bonusRegiona(id)
        return tacno ? puno : max(1, puno / 2)
    }

    func snabdevanje(tacno: Bool) -> Stanje {
        guard faza == .snabdevanje else { return self }
        var s = self
        let ja = trenutni
        if tacno { s.tacnih[ja.tim, default: 0] += 1 }
        var vojske = s.pojacanja(ja.id, tacno: tacno)
        // Odbrane koštaju vojske jednom po krugu: plaća se na kapitenovom potezu.
        if ja.kapiten {
            for k in s.odbrane.keys.sorted() where s.drziKontinent(ja.tim, k) {
                let cena = s.odbrane[k]!.cena
                if cena <= vojske - 1 { vojske -= cena } else { s.odbrane[k] = .brzSat }
            }
        }
        s.faza = .raspored
        s.zaRaspored = vojske
        return s
    }

    func rasporedi(_ oblastId: String) -> Stanje {
        guard faza == .raspored, zaRaspored > 0, oblasti[oblastId]?.vlasnik == trenutni.tim else { return self }
        var s = self
        s.oblasti[oblastId]!.vojske += 1
        s.zaRaspored -= 1
        if s.zaRaspored == 0 { s.faza = .napad }
        return s
    }

    /// Napada zaredom po potezu: 5 svako za sebe, 2 po igraču u timu.
    var napadaPoPotezu: Int { Set(igraci.map(\.tim)).count < igraci.count ? Pravila.bitakaUTimuPoIgracu : Pravila.bitakaPoPotezu }

    func mete(_ odakle: String) -> [String] {
        guard faza == .napad, bitaka < napadaPoPotezu,
              let izvor = oblasti[odakle], izvor.vlasnik == trenutni.tim, izvor.vojske >= 2 else { return [] }
        return Mapa.susedi(odakle).filter { oblasti[$0] != nil && oblasti[$0]?.vlasnik != izvor.vlasnik }
    }

    var mozeDaNapada: Bool { oblastiIgraca(trenutni.id).contains { !mete($0).isEmpty } }

    /// Razrešava bitku od jednog pitanja (neutralna država). `branilac` je nil kad je neutralna.
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
        let odbrana = odbranaMete(kuda)
        let k = Kontinenti.od(kuda).id
        var s = self
        if odbrana == .zamka && !napadac.tacan { gubitakNapadaca += 1 }
        if odbrana == .tvrdjava && gubitakBranioca > 0 && tvrdjava[k] != krug {
            gubitakBranioca = 0
            s.tvrdjava[k] = krug
        }

        let vojskeNapadaca = max(1, izvor.vojske - gubitakNapadaca)
        let vojskeBranioca = max(0, meta.vojske - gubitakBranioca)
        let osvojeno = vojskeBranioca == 0
        var proboj = false
        var plen = false

        if osvojeno {
            let prelazi = vojskeNapadaca - 1
            s.niz += 1
            proboj = s.niz % Pravila.probojSvakih == 0
            plen = meta.vlasnik != nil && igraci.contains { $0.prestonica == kuda && $0.tim == meta.vlasnik }
            s.oblasti[odakle] = StanjeOblasti(vlasnik: izvor.vlasnik, vojske: 1)
            s.oblasti[kuda] = StanjeOblasti(
                vlasnik: izvor.vlasnik,
                vojske: max(1, prelazi) + (proboj ? Pravila.probojBonus : 0) + (plen ? Pravila.plenPrestonice : 0))
        } else {
            s.oblasti[odakle]!.vojske = vojskeNapadaca
            s.oblasti[kuda]!.vojske = vojskeBranioca
        }
        if napadac.tacan { s.tacnih[trenutni.tim, default: 0] += 1 }
        if branilac?.tacan == true, let v = meta.vlasnik { s.tacnih[v, default: 0] += 1 }
        s.posleBitke()
        let ishod = Ishod(gubitakNapadaca: izvor.vojske - vojskeNapadaca, gubitakBranioca: meta.vojske - vojskeBranioca,
                          osvojeno: osvojeno, proboj: proboj, plen: plen)
        return (s, ishod)
    }

    /// Bitka od 5 pitanja za državu koju drži igrač: više tačnih, pa brži; isto ide braniocu.
    func razresiBitkuSkorom(odakle: String, kuda: String, napadac: Skor, branilac: Skor) -> (Stanje, Ishod) {
        precondition(mete(odakle).contains(kuda), "Napad \(odakle) → \(kuda) nije dozvoljen")
        let izvor = oblasti[odakle]!
        let meta = oblasti[kuda]!
        let braniTim = meta.vlasnik!
        let napadaTim = izvor.vlasnik!
        let odbrana = odbranaMete(kuda)
        let k = Kontinenti.od(kuda).id
        let potrebno = odbrana == .prednost ? 2 : 1
        let razlika = napadac.tacnih - branilac.tacnih
        var pobedio = razlika >= potrebno || (potrebno == 1 && razlika == 0 && napadac.ms < branilac.ms)
        var s = self
        var gubitakBranioca = 0
        var tvrdjavaDrzi = false
        if pobedio && odbrana == .tvrdjava && tvrdjava[k] != krug {
            // Prvi poraz u krugu: branilac zadržava državu, ali gubi jednu vojsku.
            pobedio = false
            tvrdjavaDrzi = true
            gubitakBranioca = min(1, meta.vojske - 1)
            s.tvrdjava[k] = krug
        }
        var proboj = false
        var plen = false
        var gubitakNapadaca = 0
        if pobedio {
            s.niz += 1
            proboj = s.niz % Pravila.probojSvakih == 0
            plen = igraci.contains { $0.prestonica == kuda && $0.tim == braniTim }
            gubitakBranioca = meta.vojske
            s.oblasti[odakle] = StanjeOblasti(vlasnik: napadaTim, vojske: 1)
            s.oblasti[kuda] = StanjeOblasti(vlasnik: napadaTim,
                                            vojske: max(1, izvor.vojske - 1) + (proboj ? Pravila.probojBonus : 0) + (plen ? Pravila.plenPrestonice : 0))
        } else if tvrdjavaDrzi {
            // Tvrđava je izdržala: napadač ostaje u svojoj državi, branilac gubi vojsku.
            s.oblasti[kuda]!.vojske = meta.vojske - gubitakBranioca
        } else {
            // Izgubljena bitka protiv igrača: branilac uzima državu iz koje se napadalo, sa preživelim vojskama.
            let ostaje = max(1, izvor.vojske - Pravila.gubitakPorazenogNapadaca - (odbrana == .zamka ? 1 : 0))
            gubitakNapadaca = izvor.vojske
            s.oblasti[odakle] = StanjeOblasti(vlasnik: braniTim, vojske: ostaje)
        }
        s.tacnih[napadaTim, default: 0] += napadac.tacnih
        s.tacnih[braniTim, default: 0] += branilac.tacnih
        s.bonusPomoci[pobedio ? napadaTim : braniTim, default: 0] += Pravila.bonusPomociPobedniku
        s.posleBitke()
        return (s, Ishod(gubitakNapadaca: gubitakNapadaca, gubitakBranioca: gubitakBranioca, osvojeno: pobedio, proboj: proboj, plen: plen,
                         izgubljenaDrzava: !pobedio && !tvrdjavaDrzi))
    }

    private mutating func posleBitke() {
        for i in igraci.indices where !igraci[i].ispao && !oblasti.values.contains(where: { $0.vlasnik == igraci[i].tim }) {
            igraci[i].ispao = true
        }
        bitaka += 1
        if pobednik == nil, let t = timSaIspunjenomMisijom { pobednik = t; faza = .kraj }
    }

    /// Jednom po potezu: vojske između dve susedne svoje oblasti, u izvoru ostaje 1.
    func utvrdi(odakle: String, kuda: String, broj: Int) -> Stanje {
        let tim = trenutni.tim
        guard faza == .napad, !utvrdjeno, let a = oblasti[odakle], let b = oblasti[kuda],
              a.vlasnik == tim, b.vlasnik == tim, Mapa.susedi(odakle).contains(kuda) else { return self }
        let n = min(broj, a.vojske - 1)
        guard n > 0 else { return self }
        var s = self
        s.utvrdjeno = true
        s.oblasti[odakle]!.vojske -= n
        s.oblasti[kuda]!.vojske += n
        return s
    }

    /// Isteklo vreme na potezu igrača `id`: bez ijednog napada to je propušten potez; treći zaredom ga izbacuje,
    /// a države njegovog tima (ako niko iz tima nije ostao) postaju neutralne sa pola vojske. Napad u potezu briše niz.
    func isteklo(_ id: String) -> Stanje {
        var s = self
        var p = s.propusteno ?? [:]
        p[id] = bitaka > 0 ? 0 : (p[id] ?? 0) + 1
        s.propusteno = p
        if (p[id] ?? 0) >= Pravila.propustenihDoIspadanja, let i = s.igraci.firstIndex(where: { $0.id == id }) {
            s.igraci[i].ispao = true
            let tim = s.igraci[i].tim
            if !s.igraci.contains(where: { $0.tim == tim && !$0.ispao }) {
                for (k, o) in s.oblasti where o.vlasnik == tim { s.oblasti[k] = StanjeOblasti(vlasnik: nil, vojske: max(1, o.vojske / 2)) }
            }
        }
        return s.zavrsiPotez()
    }

    func zavrsiPotez() -> Stanje {
        guard faza != .kraj else { return self }
        var s = self
        if Set(igraci.filter { !$0.ispao }.map(\.tim)).count <= 1 { s.faza = .kraj; return s }
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
        let tim = timOd(id)
        let moje = oblastiIgraca(id)
        let vojske = moje.reduce(0) { $0 + (oblasti[$1]?.vojske ?? 0) }
        let prestonica = igraci.first { $0.id == id }.map { oblasti[$0.prestonica]?.vlasnik == tim ? Pravila.poeniPrestonica : 0 } ?? 0
        return moje.count * Pravila.poeniPoOblasti + vojske + bonusRegiona(id) * Pravila.poeniPoBonusu + prestonica
    }

    var poredak: [(igrac: Igrac, poeni: Int)] {
        igraci.map { ($0, poeni($0.id)) }.sorted { $0.1 > $1.1 }
    }

    // MARK: Kontinenti i odbrane

    func drziKontinent(_ tim: String, _ kontinentId: String) -> Bool {
        let l = Kontinenti.oblasti(kontinentId)
        return !l.isEmpty && l.allSatisfy { oblasti[$0]?.vlasnik == tim }
    }

    /// Odbrana koja štiti metu: važi samo dok vlasnik mete drži ceo njen kontinent.
    func odbranaMete(_ kuda: String) -> Odbrana? {
        guard let v = oblasti[kuda]?.vlasnik else { return nil }
        let k = Kontinenti.od(kuda).id
        guard let o = odbrane[k], drziKontinent(v, k) else { return nil }
        return o
    }

    struct Uslov: Equatable { let sekundi: Int; let bezPomoci: Bool; let tesko: Bool; let pitanja: Int; let temaBranioca: Bool; let prednost: Int }

    func uslovBitke(_ kuda: String) -> Uslov {
        let o = odbranaMete(kuda)
        return Uslov(sekundi: o == .brzSat ? Pravila.sekundiBrzSat : Pravila.sekundiPoPitanju, bezPomoci: o == .bezPomoci,
                     tesko: o == .teskoPitanje, pitanja: oblasti[kuda]?.vlasnik != nil ? Pravila.pitanjaUBitci : 1,
                     temaBranioca: o == .temaBranioca, prednost: o == .prednost ? 2 : 0)
    }

    /// Kapiten tima koji drži ceo kontinent bira odbranu; menja je najviše jednom po krugu.
    func postaviOdbranu(_ kontinentId: String, _ o: Odbrana) -> Stanje {
        let ja = trenutni
        guard ja.kapiten, faza != .kraj, drziKontinent(ja.tim, kontinentId), promenaOdbrane[kontinentId] != krug else { return self }
        var s = self
        s.odbrane[kontinentId] = o
        s.promenaOdbrane[kontinentId] = krug
        return s
    }

    /// Odbrana kontinenta: kad cilj ili jak rival dira kontinent, skuplja „Prednost” (napadaču trebaju 2 tačna više), inače „Brz sat”.
    func botOdbrana() -> Stanje {
        var s = self
        let tim = trenutni.tim
        let cilj = ciljBota(tim)
        for k in Kontinenti.svi where s.odbrane[k.id] == nil && s.drziKontinent(tim, k.id) {
            let ugrozen = Kontinenti.oblasti(k.id).contains { s.pretnja($0, tim: tim, cilj: cilj) >= 4 }
            s = s.postaviOdbranu(k.id, ugrozen ? .prednost : .brzSat)
        }
        return s
    }

    func iskoristiBonusPomoc(_ tim: String) -> Stanje? {
        guard (bonusPomoci[tim] ?? 0) > 0 else { return nil }
        var s = self
        s.bonusPomoci[tim]! -= 1
        return s
    }

    // MARK: Misije

    private func udeo(_ tim: String, _ ids: [String]) -> Double {
        let sve = ids.flatMap(Kontinenti.oblasti)
        return Double(sve.filter { oblasti[$0]?.vlasnik == tim }.count) / Double(sve.count)
    }

    /// Napredak misije tima od 0 do 1 (1 = ispunjena).
    func napredakMisije(_ tim: String) -> Double {
        let drzave = Mapa.oblasti.filter { oblasti[$0.id]?.vlasnik == tim }
        func do1(_ x: Double) -> Double { min(1, x) }
        switch misije[tim] {
        case "evr-jam": return udeo(tim, ["evr", "jam"])
        case "evr-oke-jos":
            let osnova = udeo(tim, ["evr", "oke"])
            let ostali = Kontinenti.svi.filter { $0.id != "evr" && $0.id != "oke" }.map { udeo(tim, [$0.id]) }
            return osnova < 1 ? osnova * 0.75 : 0.75 + 0.25 * (ostali.max() ?? 0)
        case "sam-jam": return udeo(tim, ["sam", "jam"])
        case "azi-jam": return udeo(tim, ["azi", "jam"])
        case "afr-oke": return udeo(tim, ["afr", "oke"])
        case "sam-oke": return udeo(tim, ["sam", "oke"])
        case "drzava60": return do1(Double(drzave.count) / 60)
        case "drzava45x2": return do1(Double(drzave.filter { (oblasti[$0.id]?.vojske ?? 0) >= 2 }.count) / 45)
        case "regiona8":
            return do1(Double(Mapa.regioni.filter { r in Mapa.oblasti.filter { $0.region == r.id }.allSatisfy { oblasti[$0.id]?.vlasnik == tim } }.count) / 8)
        case "prestonice2": return do1(Double(igraci.filter { $0.tim != tim && oblasti[$0.prestonica]?.vlasnik == tim }.count) / 2)
        case "izbaci":
            let meta = metaMisije[tim]
            return igraci.filter { $0.tim == meta }.allSatisfy(\.ispao) ? 1 : 0
        case "tacnih25": return do1(Double(tacnih[tim] ?? 0) / 25) * 0.5 + do1(Double(drzave.count) / 30) * 0.5
        default: return 0
        }
    }

    var timSaIspunjenomMisijom: String? { misije.keys.sorted().first { napredakMisije($0) >= 1 } }

    private mutating func dodeliMisije(_ slucajno: inout Slucajno) {
        var timovi: [String] = []
        for p in igraci where !timovi.contains(p.tim) { timovi.append(p.tim) }
        let pojedinacno = timovi.count == igraci.count
        var ponuda = Misije.sve.filter { pojedinacno || !$0.samoPojedinacno }.map(\.id)
        for i in stride(from: ponuda.count - 1, to: 0, by: -1) {
            let j = Int(slucajno.sledeci() * Double(i + 1))
            ponuda.swapAt(i, j)
        }
        for (i, tim) in timovi.enumerated() {
            let m = ponuda[i % ponuda.count]
            misije[tim] = m
            if m == "izbaci" {
                let drugi = timovi.filter { $0 != tim }
                metaMisije[tim] = drugi[Int(slucajno.sledeci() * Double(drugi.count))]
            }
        }
    }

    static func redosledIzbora(_ timovi: [String], krugova: Int = 1) -> [String] {
        (0..<krugova).flatMap { $0 % 2 == 0 ? timovi : timovi.reversed() }
    }

    // MARK: Botovi

    func botOdgovor(_ slucajno: inout Slucajno) -> Odgovor {
        Odgovor(tacan: slucajno.sledeci() < tacnostBota, ms: 3000 + Int(slucajno.sledeci() * 9000))
    }

    func botSkor(_ slucajno: inout Slucajno, pitanja: Int = Pravila.pitanjaUBitci) -> Skor {
        var t = 0, ms = 0
        for _ in 0..<pitanja { let o = botOdgovor(&slucajno); if o.tacan { t += 1 }; ms += o.ms }
        return Skor(tacnih: t, ms: ms)
    }

    // MARK: Mozak bota (docs/OSVAJANJE-BOT.md)
    //
    // Bot misli u četiri koraka: koga cilja, gde stavlja vojsku, koju bitku bira (šansa × vrednost − rizik),
    // pa pred kraj poteza prebacuje vojsku iz unutrašnjosti na najugroženiju granicu. Narav (napadač, graditelj,
    // oprezan) menja pragove, a težina koliko često bot „pogreši” izbor. Pitanja i dalje odlučuje `tacnostBota`.

    enum Narav { case napadac, graditelj, oprezan }

    /// Stalna narav po id-ju (ista na svakom telefonu i u svakoj partiji).
    static func narav(_ id: String) -> Narav {
        switch id.unicodeScalars.reduce(0, { $0 + Int($1.value) }) % 3 { case 0: .napadac; case 1: .graditelj; default: .oprezan }
    }

    /// Ljudi u partiji: igrač na ovom telefonu ili pravi nalog („u:”).
    private func jeCovek(_ i: Igrac) -> Bool { i.covek || i.id.hasPrefix("u:") }

    /// Snaga tima: države, vojske i celi regioni (bonus vojske svakog kruga).
    func snaga(_ tim: String) -> Double {
        let moje = oblasti.values.filter { $0.vlasnik == tim }
        return Double(moje.count) + Double(moje.reduce(0) { $0 + $1.vojske }) * 0.5 + Double(bonusRegiona(tim)) * 3
    }

    /// Koga bot cilja: u partiji sa jednim čovekom (ili jednim timom ljudi) svi botovi idu na njega; inače na najjačeg rivala.
    func ciljBota(_ tim: String) -> String? {
        let zivi = igraci.filter { !$0.ispao && $0.tim != tim }
        let ljudi = Set(zivi.filter(jeCovek).map(\.tim))
        if ljudi.count == 1, !igraci.contains(where: { jeCovek($0) && $0.tim == tim }) { return ljudi.first }
        return Set(zivi.map(\.tim)).max { snaga($0) < snaga($1) }
    }

    /// Koliko tuđe vojske preti državi (cilj se računa jače).
    private func pretnja(_ id: String, tim: String, cilj: String?) -> Double {
        Mapa.susedi(id).reduce(0) { zbir, n in
            guard let o = oblasti[n], let v = o.vlasnik, v != tim else { return zbir }
            return zbir + Double(o.vojske) * (v == cilj ? 1.5 : 1)
        }
    }

    /// Koliko država regiona još fali timu.
    private func fali(_ region: String, tim: String) -> Int {
        Mapa.oblasti.filter { $0.region == region && oblasti[$0.id] != nil && oblasti[$0.id]?.vlasnik != tim }.count
    }

    /// Šansa da napadač sa tačnošću `a` dobije bitku od `n` pitanja protiv branioca `b`: više tačnih,
    /// kod jednakog broja brži (pola-pola); `prednost` traži 2 tačna više.
    static func sansaBitke(_ a: Double, _ b: Double, n: Int, prednost: Bool) -> Double {
        func bin(_ p: Double) -> [Double] {
            (0...n).map { k in
                var c = 1.0
                for i in 0..<k { c = c * Double(n - i) / Double(i + 1) }
                return c * pow(p, Double(k)) * pow(1 - p, Double(n - k))
            }
        }
        let pa = bin(a), pb = bin(b)
        var w = 0.0
        for i in 0...n { for j in 0...n {
            let r = i - j
            if prednost { if r >= 2 { w += pa[i] * pb[j] } }
            else if r > 0 { w += pa[i] * pb[j] } else if r == 0 { w += pa[i] * pb[j] * 0.5 }
        } }
        return w
    }

    /// Vrednost države za tim: region koji se zatvara, tuđi region koji se ruši, prestonica, cilj, kontinent iz misije.
    private func vrednost(_ kuda: String, tim: String, cilj: String?, narav: Narav) -> Double {
        let o = Mapa.oblast(kuda)
        let region = Mapa.regioni.first { $0.id == o.region }
        let bonus = Double(region?.bonus ?? 0)
        let gradnja = narav == .graditelj ? 1.4 : 1
        var v = 1.0
        let f = fali(o.region, tim: tim)
        if f == 1 { v += bonus * 1.5 * gradnja } else { v += bonus * 0.3 * gradnja / Double(max(1, f)) }
        if let vlasnik = oblasti[kuda]?.vlasnik {
            if fali(o.region, tim: vlasnik) == 0 { v += bonus * 1.2 }
            if igraci.contains(where: { $0.tim == vlasnik && $0.prestonica == kuda }) { v += 3 }
            if vlasnik == cilj { v += 1.5 }
        }
        if let m = misije[tim], m.contains(Kontinenti.od(kuda).id) { v += 0.8 }
        return v
    }

    /// Ocena napada: šansa × dobitak − (1 − šansa) × gubitak. Protiv igrača poraz odnosi i državu iz koje se napada.
    func ocenaNapada(odakle: String, kuda: String) -> Double {
        let tim = trenutni.tim
        let nar = Stanje.narav(trenutni.id)
        let cilj = ciljBota(tim)
        guard let izvor = oblasti[odakle], let meta = oblasti[kuda] else { return -.infinity }
        let dobitak = vrednost(kuda, tim: tim, cilj: cilj, narav: nar)
        let p: Double
        var gubitak: Double
        if let vlasnik = meta.vlasnik {
            let branilac = igraci.first { $0.tim == vlasnik }.map(jeCovek) == true ? 0.65 : tacnostBota
            p = Stanje.sansaBitke(tacnostBota, branilac, n: uslovBitke(kuda).pitanja, prednost: odbranaMete(kuda) == .prednost)
            gubitak = 1 + Double(max(0, izvor.vojske - Pravila.gubitakPorazenogNapadaca)) * 0.4
            if igraci.contains(where: { $0.tim == tim && $0.prestonica == odakle }) { gubitak += 4 }
            if fali(Mapa.oblast(odakle).region, tim: tim) == 0 { gubitak += Double(Mapa.regioni.first { $0.id == Mapa.oblast(odakle).region }?.bonus ?? 0) }
        } else {
            p = tacnostBota
            gubitak = 0.5
        }
        if nar == .oprezan { gubitak *= 1.3 }
        return p * dobitak - (1 - p) * gubitak
    }

    /// Prag ispod kog bot ne napada; slabija vojska u izvoru traži više.
    private func pragNapada(_ nar: Narav) -> Double {
        switch nar { case .napadac: 0.1; case .graditelj: 0.25; case .oprezan: 0.5 }
    }

    /// Koliko često bot uzme lošiji potez (lako 35%, normalno 12%, teško nikad).
    private var greskaBota: Double { tacnostBota < 0.55 ? 0.35 : tacnostBota < 0.7 ? 0.12 : 0 }

    func botRasporedi() -> Stanje {
        var s = self
        let tim = trenutni.tim
        let cilj = ciljBota(tim)
        while s.faza == .raspored {
            let moje = s.oblastiIgraca(s.trenutni.id)
            guard let prva = moje.first else { break }
            // Vojska ide tamo gde je najveća pretnja ili odakle se zatvara region; prestonica se čuva.
            func ocena(_ id: String) -> Double {
                var v = s.pretnja(id, tim: tim, cilj: cilj) - Double(s.oblasti[id]?.vojske ?? 0) * 0.6
                if Mapa.susedi(id).contains(where: { n in s.oblasti[n] != nil && s.oblasti[n]?.vlasnik != tim && s.fali(Mapa.oblast(n).region, tim: tim) == 1 }) { v += 3 }
                if s.igraci.contains(where: { $0.tim == tim && $0.prestonica == id }) { v += 1.5 }
                return v
            }
            let granica = moje.filter { s.pretnja($0, tim: tim, cilj: cilj) > 0 }
            let cel = (granica.isEmpty ? moje : granica).max { ocena($0) < ocena($1) } ?? prva
            s = s.rasporedi(cel)
        }
        return s
    }

    func botSledeciNapad() -> (odakle: String, kuda: String)? {
        let nar = Stanje.narav(trenutni.id)
        var opcije: [(String, String, Double)] = []
        for odakle in oblastiIgraca(trenutni.id) {
            for kuda in mete(odakle) { opcije.append((odakle, kuda, ocenaNapada(odakle: odakle, kuda: kuda))) }
        }
        guard !opcije.isEmpty else { return nil }
        // Šum je vezan za krug i bitku, da isti potez ne ispadne drugačije na dva telefona.
        var r = Slucajno(seme: UInt32(truncatingIfNeeded: krug * 7919 + naPotezu * 131 + bitaka * 17 + 1))
        if r.sledeci() < greskaBota {
            let losije = opcije.filter { $0.2 > -1 }
            if !losije.isEmpty { let o = losije[Int(r.sledeci() * Double(losije.count))]; return (o.0, o.1) }
        }
        guard let najbolja = opcije.max(by: { $0.2 < $1.2 }), najbolja.2 >= pragNapada(nar) else { return nil }
        return (najbolja.0, najbolja.1)
    }

    /// Pred kraj poteza: vojska iz unutrašnjosti (bez tuđih suseda) ide na najugroženiju susednu granicu.
    func botUtvrdi() -> Stanje {
        let tim = trenutni.tim
        let cilj = ciljBota(tim)
        var najbolje: (String, String, Double)?
        for id in oblastiIgraca(trenutni.id) where (oblasti[id]?.vojske ?? 0) > 1 && pretnja(id, tim: tim, cilj: cilj) == 0 {
            for n in Mapa.susedi(id) where oblasti[n]?.vlasnik == tim {
                let p = pretnja(n, tim: tim, cilj: cilj)
                if p > 0, najbolje.map({ p > $0.2 }) ?? true { najbolje = (id, n, p) }
            }
        }
        guard let (odakle, kuda, _) = najbolje else { return self }
        return utvrdi(odakle: odakle, kuda: kuda, broj: (oblasti[odakle]?.vojske ?? 1) - 1)
    }
}
