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
    /// Nepoznat ID (zastarela sačuvana partija) ne sme da obori igru: u probi se javlja, u izdanju se crta prva država.
    static func oblast(_ id: String) -> Oblast {
        if let o = poId[id] { return o }
        assertionFailure("nepoznata oblast \(id)")
        return svet.drzave[0]
    }
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
    /// Kontranapad posle odbrane sa bar ovoliko tačnih (vlasnik 04.11).
    static let tacnihZaKontranapad = 3
    /// Ratna karta za niz: dobijene bitke zaredom i osvojene države u jednom potezu.
    static let pobedaZaKartu = 3
    /// Saveznici mogu da zamene tajne misije do ovog kruga.
    static let zamenaMisijaDoKruga = 5
    static let osvajanjaZaKartu = 2
    /// Opsada: ovoliko neuspelih napada zaredom na prestonicu daje braniocu kartu.
    static let napadaZaOpsadu = 2
    /// Savezničko pojačanje: vojske koje saveznik šalje jednom po krugu.
    static let vojskiPomociSavezniku = 2
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
    /// Vreme za odgovor u bitki (vlasnik 03.11: 20 s podrazumevano).
    static let sekundiPoPitanju = 20
    static let sekundiBrzSat = 8
    // Strategija (Strategija.swift, docs/OSVAJANJE-STRATEGIJA.md).
    /// Višak vojske u bitki sa igračem vredi najviše ovoliko tačnih odgovora.
    static let najvecaPrednostVojske = 2
    /// Napad na neutralnu državu sa bar ovoliko vojske: greška ne košta vojsku.
    static let vojskiBezGubitkaNaNeutralnoj = 3
    static let najviseKarata = 5
    static let vojskiPojacanja = 2
    static let dogadjajSvakih = 4
    static let trajanjeDogadjaja = 2
    static let sekundiMudraci = 5
    static let sekundiKarneval = 10
    static let napadaViseKonjica = 2
    // Drugi talas (Strategija2.swift).
    static let najveciUlog = 2
    static let korakaMarsa = 3
    static let nagradaPohoda = 3
    static let vojskiPiramide = 2
    static let sekundiOpera = 5
    /// Bitka od 5 pitanja: povlačenje je moguće posle ovoliko odgovora.
    static let povlacenjePosle = 2
}

enum Tezina: String, CaseIterable, Identifiable {
    case lako, normalno, tesko
    var id: String { rawValue }
    var tacnost: Double { switch self { case .lako: 0.5; case .normalno: 0.55; case .tesko: 0.75 } }
    var ime: String { switch self { case .lako: "Lako"; case .normalno: "Normalno"; case .tesko: "Teško" } }
    var opis: String {
        switch self {
        case .lako: "Rivali greše svako drugo pitanje"
        case .normalno: "Rivali znaju nešto više od pola"
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
    /// Vrsta vojske izabrana pre partije (Strategija.swift); nil u starim stanjima.
    var vojska: VrstaVojske? = nil
}

/// Igrač za novu partiju (čekaonica): bez prestonice, ona se bira na početku.
struct NoviIgrac { let id: String; let ime: String; var boja: UInt32; let covek: Bool; var tim: String? = nil; var kapiten = true; var vojska: VrstaVojske? = nil
    /// Stalni savez: slovo strane (saveznici imaju svoj tim i boju, a istu stranu); nil = bez saveza.
    var strana: String? = nil }

struct StanjeOblasti: Equatable, Codable { var vlasnik: String?; var vojske: Int }

enum Faza: String, Equatable, Codable { case snabdevanje, raspored, napad, kraj }

struct Odgovor: Equatable { let tacan: Bool; let ms: Int }

/// Rezultat jedne strane u bitki od 5 pitanja.
struct Skor: Equatable, Codable {
    let tacnih: Int; let ms: Int
    /// Moći vojske korišćene u bitki koje menjaju ishod (Plen, Utvrđenje, Temelj, Radionica, Garnizon, Špijunska mreža);
    /// idu uz skor, pa ih primenjuje i telefon drugog igrača.
    var efekti: [String]? = nil
    func ima(_ p: PomocVojske) -> Bool { efekti?.contains(p.rawValue) == true }
}

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

struct Misija: Equatable { let id: String; let tekst: String; var samoPojedinacno = false; var najmanjeRivala = 1 }

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
        // Proširenje 03.11.2026 (vlasnik: „dosta tajnih zadataka da ne bude uvek isto”).
        Misija(id: "evr-afr", tekst: "Osvoji Evropu i Afriku."),
        Misija(id: "sam-evr", tekst: "Osvoji Severnu Ameriku i Evropu."),
        Misija(id: "azi-oke", tekst: "Osvoji Aziju i Okeaniju."),
        Misija(id: "afr-jam", tekst: "Osvoji Afriku i Južnu Ameriku."),
        Misija(id: "kontinenta2", tekst: "Drži bilo koja dva cela kontinenta."),
        Misija(id: "drzava50", tekst: "Drži 50 država."),
        Misija(id: "regiona10", tekst: "Drži 10 celih regiona."),
        Misija(id: "regiona6-kontinent", tekst: "Drži 6 celih regiona i bar jedan ceo kontinent."),
        Misija(id: "prestonice3", tekst: "Zauzmi prestonice tri rivala.", najmanjeRivala: 3),
        Misija(id: "vojske150", tekst: "Imaj 150 vojski na mapi."),
        Misija(id: "tacnih40", tekst: "Odgovori tačno na 40 pitanja."),
        Misija(id: "pobeda10", tekst: "Dobij 10 bitaka protiv igrača (napad ili odbrana)."),
        Misija(id: "ostrva", tekst: "Drži celu Okeaniju i Karibe."),
        Misija(id: "put-svile", tekst: "Drži Bliski istok, Centralnu i Južnu Aziju i Istočnu Aziju."),
        Misija(id: "mediteran", tekst: "Drži Južnu Evropu, Severnu Afriku i Bliski istok."),
        Misija(id: "svuda4", tekst: "Drži bar 4 države na svakom kontinentu."),
        Misija(id: "prestonica35", tekst: "Sačuvaj svoju prestonicu i drži 35 država."),
        Misija(id: "amerike-pola", tekst: "Drži celu Južnu Ameriku i pola Severne Amerike."),
        Misija(id: "cuda3", tekst: "Drži tri čuda sveta (Piramide, Kineski zid, Akropolj, Maču Pikču, Kip slobode, Sidnejska opera)."),
        Misija(id: "pohodi3", tekst: "Ispuni tri najavljena pohoda i drži bar 25 država."),
        // Proširenje 04.11.2026 (vlasnik: „više od 30–50 tajnih misija”): 62 ukupno.
        Misija(id: "evr-bli", tekst: "Osvoji Evropu i Bliski istok."),
        Misija(id: "sam-kar-jam", tekst: "Drži Severnu Ameriku, Karibe i Južnu Ameriku."),
        Misija(id: "afr-bli", tekst: "Osvoji Afriku i Bliski istok."),
        Misija(id: "azi-ceo", tekst: "Osvoji celu Aziju."),
        Misija(id: "afr-ceo", tekst: "Osvoji celu Afriku i drži 40 država."),
        Misija(id: "evr-ceo-prest", tekst: "Osvoji celu Evropu i zauzmi jednu tuđu prestonicu."),
        Misija(id: "kontinenta3", tekst: "Drži bilo koja tri cela kontinenta."),
        Misija(id: "drzava70", tekst: "Drži 70 država."),
        Misija(id: "drzava40x3", tekst: "Drži 40 država sa najmanje 3 vojske u svakoj."),
        Misija(id: "regiona12", tekst: "Drži 12 celih regiona."),
        Misija(id: "vojske200", tekst: "Imaj 200 vojski na mapi."),
        Misija(id: "tacnih60", tekst: "Odgovori tačno na 60 pitanja i drži bar 35 država."),
        Misija(id: "pobeda15", tekst: "Dobij 15 bitaka protiv igrača."),
        Misija(id: "cuda4", tekst: "Drži četiri čuda sveta i bar 30 država."),
        Misija(id: "cuda-kontinent", tekst: "Drži dva čuda sveta i jedan ceo kontinent."),
        Misija(id: "prestonice-svoja", tekst: "Sačuvaj svoju prestonicu i zauzmi prestonice dva rivala.", najmanjeRivala: 2),
        Misija(id: "svuda6", tekst: "Drži bar 6 država na svakom kontinentu."),
        Misija(id: "severna-hem", tekst: "Drži Severnu Ameriku, Severnu i Zapadnu Evropu."),
        Misija(id: "juzna-hem", tekst: "Drži Južnu Ameriku, Južnu Afriku i Okeaniju."),
        Misija(id: "indijski", tekst: "Drži Istočnu Afriku, Bliski istok i Centralnu i Južnu Aziju."),
        Misija(id: "pacifik", tekst: "Drži Istočnu Aziju, Jugoistočnu Aziju i Okeaniju."),
        Misija(id: "atlantik", tekst: "Drži Zapadnu Afriku, Zapadnu Evropu i Južnu Ameriku."),
        Misija(id: "balkan-bli", tekst: "Drži Južnu Evropu, Istočnu Evropu i Bliski istok."),
        Misija(id: "crna-afrika", tekst: "Drži Zapadnu, Centralnu i Južnu Afriku."),
        Misija(id: "evroazija", tekst: "Drži Istočnu Evropu, Centralnu i Južnu Aziju i Istočnu Aziju."),
        Misija(id: "morske5", tekst: "Drži obe obale 5 morskih veza (npr. Brazil i Senegal)."),
        Misija(id: "granica", tekst: "Drži 25 država i nijednu sa samo 1 vojskom."),
        Misija(id: "regiona8-prest", tekst: "Drži 8 celih regiona i svoju prestonicu."),
        Misija(id: "pohodi4", tekst: "Ispuni četiri najavljena pohoda i drži bar 30 država."),
        Misija(id: "kontinent-svuda", tekst: "Drži jedan ceo kontinent i bar 3 države na svakom drugom."),
        Misija(id: "izbaci2", tekst: "Izbaci dva rivala iz igre.", najmanjeRivala: 2),
        Misija(id: "bez-poraza", tekst: "Dobij 8 bitaka protiv igrača i drži 30 država."),
    ]
    static func tekst(_ id: String?) -> String { sve.first { $0.id == id }?.tekst ?? "" }
    /// Misije čiji brojevi (države, regioni, vojske) zavise od broja strana; tačni odgovori i prestonice ne.
    static let skalirane: Set<String> = ["drzava60", "drzava45x2", "regiona8", "drzava50", "regiona10", "regiona6-kontinent", "vojske150", "prestonica35",
                                         "afr-ceo", "drzava70", "drzava40x3", "regiona12", "vojske200", "tacnih60", "cuda4", "granica", "regiona8-prest",
                                         "pohodi4", "bez-poraza"]
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
    // Strategija (opciono, da stara stanja sa servera i dalje čitaju).
    var karteTimova: [String: [Karta]]?
    var zamrznuto: [String: Int]?
    var savezi: [String: Int]?
    var predloziSaveza: [String]?
    var poruke: [BrzaPoruka]?
    var dogadjaj: Dogadjaj?
    var pobedaBitaka: [String: Int]?
    var ulog: Int?
    /// Pomoći vojske: „tim|pomoć” → krug u kom je iskorišćena.
    var pomociVojske: [String: Int]?
    var pohodi: [String: String]?
    var uspeliPohodi: [String: Int]?
    var izdajnici: [String]?
    var ultimatumKrug: [String: Int]?
    var odbijeniUltimatumi: [String: Int]?
    /// Seme ove partije (vlasnik 03.11: botovi su uvek birali iste države i poteze). Iz njega su narav i vojska botova
    /// i šum njihovih odluka; deli se preko servera, pa je partija ista na svakom telefonu. nil = staro stanje.
    var seme: UInt32?
    /// Pre prvog kruga: pravi igrači (prvi iz svakog tima) koji još biraju države i vuku tajnu misiju, redom
    /// (vlasnik 04.11: „prvo da se raspodelimo, pa da vučemo zadatke”). nil = staro stanje ili partija bez postavke.
    var cekaPostavku: [String]?
    /// Stalni savez (vlasnik 04.11): tim → strana. Saveznici imaju svoje boje, vojske i države, ali se ne napadaju i pobeđuju zajedno.
    var strane: [String: String]?
    /// Kontranapad: tim koji je odbranio državu sa 3+ tačna dobija na sledećem potezu napad više i +1 prednost iz osvojene države.
    var kontranapad: [String: String]?
    /// Opsada prestonice: neuspeli napadi zaredom na prestonicu; drugi daje braniocu ratnu kartu.
    var opsada: [String: Int]?
    /// Savezničko pojačanje: tim → krug u kom je poslao 2 vojske savezniku (jednom po krugu).
    var pomocSavezniku: [String: Int]?
    /// Tim → krug u kom je ispunio misiju (pobeđuje ako je drži do početka svog sledećeg poteza).
    var misijaOd: [String: Int]?
    /// Utvrđenje (Graditelji): država → krug do kog napadaču treba jedan tačan više.
    var bedemi: [String: Int]?
    /// Dobijene bitke zaredom po timu (3 = karta).
    var pobedeZaredom: [String: Int]?
    /// Raskid saveza: tim → krug posle kog sme da bira novog saveznika.
    var raskid: [String: Int]?
    /// Kazna za izdaju: tim → poslednji krug bez moći vojske i bez pomoći saveznika.
    var kaznaIzdaje: [String: Int]?
    /// Broj izdaja po timu (za profil).
    var izdaje: [String: Int]?
    /// Predlozi zamene misija „od>za” (dok drugi ne predloži isto, ili bot prihvati).
    var predloziZamene: [String]?
    /// Poslednje savezničko pojačanje (od tima, za tim, iz države, u državu), da primalac vidi šta je stiglo.
    var poslednjaPomoc: [String]?

    var trenutni: Igrac { igraci[naPotezu] }

    /// Ceo broj iz id-a pomešan sa semenom partije (za narav, vojsku i šum bota).
    static func mesaj(_ id: String, _ seme: UInt32, _ dodatak: Int = 0) -> Double {
        let h = id.unicodeScalars.reduce(UInt32(2166136261)) { ($0 ^ $1.value) &* 16777619 }
        var r = Slucajno(seme: h ^ seme ^ UInt32(truncatingIfNeeded: dodatak &* 2654435761))
        return r.sledeci()
    }

    /// Fisher–Yates mešanje istim generatorom (ponovljivo iz semena).
    static func promesaj<T>(_ niz: [T], _ r: inout Slucajno) -> [T] {
        var n = niz
        for i in stride(from: n.count - 1, to: 0, by: -1) { n.swapAt(i, Int(r.sledeci() * Double(i + 1))) }
        return n
    }

    static let podrazumevani: [NoviIgrac] = [
        NoviIgrac(id: "ti", ime: "Ti", boja: 0x12907E, covek: true),
        NoviIgrac(id: "mimi", ime: "Mimi", boja: 0xFF5FA2, covek: false),
        NoviIgrac(id: "zig", ime: "Zig", boja: 0x6D4BC9, covek: false),
    ]

    /// Nova partija: prestonica na izabranom kontinentu (ili u regionu koji niko nema),
    /// po šest država oko nje, ostalo neutralno; po želji tajne misije.
    /// `teren` = id kontinenta: igra se samo na njemu (1 na 1 ili protiv računara), države van njega ne postoje.
    static func nova(krugova: Int, tezina: Tezina, slucajno: inout Slucajno, ime: String? = nil,
                     igraci spisak: [NoviIgrac]? = nil, pocetak: [String: String] = [:], misije: Bool = false, teren: String? = nil,
                     vojska: VrstaVojske? = nil, izbegniMisije: Set<String> = []) -> Stanje {
        // Seme iz kopije generatora: glavni niz (prestonice, misije) ostaje isti kao na vebu za isto seme.
        var kopija = slucajno
        let seme = UInt32(kopija.sledeci() * 4_294_967_295) ^ 0x9E3779B9
        var mesanje = Slucajno(seme: seme)
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
            // Čuda sveta se osvajaju, ne dobijaju na početku.
            func slobodna(_ o: Oblast) -> Bool { Mapa.susedi(o.id).filter { oblasti[$0] != nil }.count >= 3 && oblasti[o.id] != nil && oblasti[o.id]?.vlasnik == nil && Cudo.za(o.id) == nil }
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
                                prestonica: prestonica, ispao: false, tim: tim, kapiten: p.kapiten,
                                vojska: p.vojska ?? (p.covek && spisak == nil ? vojska : nil) ?? Stanje.vojskaBota(p.id, seme: p.covek ? nil : seme)))
            // Početni posed: prestonica i najbliže slobodne države po vezama (pretraga u širinu).
            var posed = [prestonica]
            var red = [prestonica]
            var vidjeno: Set = [prestonica]
            while !red.isEmpty && posed.count < Pravila.pocetnihDrzava {
                for n in promesaj(Mapa.susedi(red.removeFirst()), &mesanje) where !vidjeno.contains(n) {
                    vidjeno.insert(n)
                    red.append(n)
                    if oblasti[n] != nil && oblasti[n]?.vlasnik == nil && Cudo.za(n) == nil && posed.count < Pravila.pocetnihDrzava { posed.append(n) }
                }
            }
            for id in posed {
                oblasti[id] = StanjeOblasti(vlasnik: tim, vojske: id == prestonica ? Pravila.pocetneVojskePrestonice : Pravila.pocetneVojskeDrzave)
            }
        }
        var s = Stanje(igraci: igraci, oblasti: oblasti, krug: 1, ukupnoKrugova: krugova, naPotezu: 0, faza: .snabdevanje,
                       zaRaspored: 0, bitaka: 0, niz: 0, utvrdjeno: false, tacnostBota: tezina.tacnost)
        s.seme = seme
        s.karteTimova = [:]
        for p in s.igraci where p.kapiten && p.vojska == .izvidnica { s.karteTimova?[p.tim, default: []].append(.spijun) }
        // Saveznici od prvog kruga (čekaonica): savez traje dok se ne raskine ili izda (vlasnik 04.11).
        let saStranom = (spisak ?? []).compactMap { p in p.strana.map { (p.tim ?? p.id, $0) } }
        for (a, sa) in saStranom { for (b, sb) in saStranom where a < b && sa == sb { var sv = s.savezi ?? [:]; sv[Stanje.kljucSaveza(a, b)] = Stanje.savezDoKraja; s.savezi = sv } }
        if misije { s.dodeliMisije(&slucajno, izbegni: izbegniMisije) }
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
        let tim = timOd(id)
        let celi = Mapa.regioni.filter { r in Mapa.oblasti.filter { $0.region == r.id }.allSatisfy { oblasti[$0.id]?.vlasnik == tim } }
        // Zlatno doba Afrike duplira bonus afričkih regiona; Graditelji dobijaju +1 po celom regionu.
        let zlatno = aktivanDogadjaj("afr") ? celi.filter { r in Kontinenti.svi.first { $0.id == "afr" }!.regioni.contains(r.id) }.reduce(0) { $0 + $1.bonus } : 0
        let puno = max(Pravila.najmanjePojacanja, oblastiIgraca(id).count / Pravila.teritorijaPoVojsci) + bonusRegiona(id) + zlatno
            + (vojskaTima(tim) == .graditelji ? celi.count : 0)
        return tacno ? puno : max(1, puno / 2)
    }

    func snabdevanje(tacno: Bool) -> Stanje {
        guard faza == .snabdevanje else { return self }
        var s = self
        let ja = trenutni
        if tacno { s.tacnih[ja.tim, default: 0] += 1 }
        var vojske = s.pojacanja(ja.id, tacno: tacno) + s.proveriPohod(ja.tim)
            + (s.drziCudo(ja.tim, "EGY") ? Pravila.vojskiPiramide : 0)
        if s.drziCudo(ja.tim, "GRC") { s.dodeliKartu(ja.tim) }
        // Odsečene države (bez puta do prestonice) gube jednu vojsku po krugu.
        for id in s.odsecene(ja.tim) where (s.oblasti[id]?.vojske ?? 0) > 1 { s.oblasti[id]!.vojske -= 1 }
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
        // Pojačanja stižu samo u države povezane sa prestonicom (linije snabdevanja).
        guard faza == .raspored, zaRaspored > 0, oblasti[oblastId]?.vlasnik == trenutni.tim, snabdevene(trenutni.tim).contains(oblastId) else { return self }
        var s = self
        s.oblasti[oblastId]!.vojske += 1
        s.zaRaspored -= 1
        if s.zaRaspored == 0 { s.faza = .napad }
        return s
    }

    /// Napada zaredom po potezu: 5 svako za sebe, 2 po igraču u timu.
    var napadaPoPotezu: Int {
        (Set(igraci.map(\.tim)).count < igraci.count ? Pravila.bitakaUTimuPoIgracu : Pravila.bitakaPoPotezu)
            + (trenutni.vojska == .konjica ? Pravila.napadaViseKonjica : 0)
            + (drziCudo(trenutni.tim, "USA") ? 1 : 0)
            + (kontranapad?[trenutni.tim] != nil ? 1 : 0)
    }

    func mete(_ odakle: String) -> [String] {
        guard faza == .napad, bitaka < napadaPoPotezu,
              let izvor = oblasti[odakle], izvor.vlasnik == trenutni.tim, izvor.vojske >= 2 else { return [] }
        // Ne napada se saveznik, zamrznuta država ni Azija za vreme Monsuna.
        return Mapa.susedi(odakle).filter { id in
            guard let o = oblasti[id], o.vlasnik != izvor.vlasnik else { return false }
            if let v = o.vlasnik, uSavezu(v, izvor.vlasnik!) { return false }
            if jeZamrznuta(id) { return false }
            return !(aktivanDogadjaj("azi") && Kontinenti.od(id).id == "azi")
        }
    }

    var mozeDaNapada: Bool { oblastiIgraca(trenutni.id).contains { !mete($0).isEmpty } }

    /// Razrešava bitku od jednog pitanja (neutralna država). `branilac` je nil kad je neutralna.
    func razresiBitku(odakle: String, kuda: String, napadac: Odgovor, branilac: Odgovor?) -> (Stanje, Ishod) {
        // Vlasnik 03.11 (pad dok je Bloop napadao): dok igrač brani državu, stanje se menja (savez, zamrznuta granica…),
        // pa napad posle odbrane ume da više ne važi. Ranije je to bio precondition = pad aplikacije; sada se bitka preskače.
        guard mete(odakle).contains(kuda) else { return (self, Ishod(gubitakNapadaca: 0, gubitakBranioca: 0, osvojeno: false, proboj: false, plen: false)) }
        let izvor = oblasti[odakle]!
        let meta = oblasti[kuda]!

        var gubitakNapadaca = 0
        var gubitakBranioca = 0
        if meta.vlasnik == nil || branilac == nil {
            // Jaka vojska (3+ u napadu) ne gubi vojsku kad promaši neutralnu državu.
            if napadac.tacan { gubitakBranioca = 1 } else if izvor.vojske - 1 < Pravila.vojskiBezGubitkaNaNeutralnoj { gubitakNapadaca = 1 }
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

        if gubitakNapadaca > 0 && Teren.pustinja.contains(kuda) { gubitakNapadaca += 1 }
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
                vojske: max(1, prelazi) + (proboj ? Pravila.probojBonus : 0) + (plen ? Pravila.plenPrestonice : 0) + s.groznica(kuda))
            s.nagradiOsvajanje(izvor.vlasnik!, kuda: kuda, proboj: proboj)
            s.zabeleziPobedu(izvor.vlasnik!, true)
        } else {
            s.zabeleziPobedu(izvor.vlasnik!, false)
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
        // Vlasnik 03.11 (pad dok je Bloop napadao): dok igrač brani državu, stanje se menja (savez, zamrznuta granica…),
        // pa napad posle odbrane ume da više ne važi. Ranije je to bio precondition = pad aplikacije; sada se bitka preskače.
        guard mete(odakle).contains(kuda) else { return (self, Ishod(gubitakNapadaca: 0, gubitakBranioca: 0, osvojeno: false, proboj: false, plen: false)) }
        let izvor = oblasti[odakle]!
        let meta = oblasti[kuda]!
        let braniTim = meta.vlasnik!
        let napadaTim = izvor.vlasnik!
        let odbrana = odbranaMete(kuda)
        let k = Kontinenti.od(kuda).id
        var pobedio = osvaja(odakle: odakle, kuda: kuda, napadac: napadac, branilac: branilac)
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
                                            vojske: max(1, izvor.vojske - 1) + (proboj ? Pravila.probojBonus : 0) + (plen ? Pravila.plenPrestonice : 0) + s.groznica(kuda))
            s.nagradiOsvajanje(napadaTim, kuda: kuda, proboj: proboj)
            // Ulog: osvojena država dobija ulog, a branilac gubi još toliko iz najjače susedne države.
            if let u = ulog {
                s.oblasti[kuda]!.vojske += u
                if let n = s.najjacaPored(kuda, tim: braniTim) { s.oblasti[n]!.vojske = max(1, s.oblasti[n]!.vojske - u) }
            }
        } else if tvrdjavaDrzi {
            // Tvrđava je izdržala: napadač ostaje u svojoj državi, branilac gubi vojsku.
            s.oblasti[kuda]!.vojske = meta.vojske - gubitakBranioca
        } else {
            // Izgubljena bitka protiv igrača: branilac uzima državu iz koje se napadalo, sa preživelim vojskama.
            let ostaje = max(1, izvor.vojske - Pravila.gubitakPorazenogNapadaca - (odbrana == .zamka ? 1 : 0) - (Teren.pustinja.contains(kuda) ? 1 : 0))
            if napadac.ima(.temelj) {
                // Temelj: napadač zadržava državu, samo gubi vojsku poraza.
                gubitakNapadaca = izvor.vojske - ostaje
                s.oblasti[odakle] = StanjeOblasti(vlasnik: napadaTim, vojske: ostaje)
            } else {
                gubitakNapadaca = izvor.vojske
                s.oblasti[odakle] = StanjeOblasti(vlasnik: braniTim, vojske: ostaje)
            }
            // Ulog: napadač gubi još toliko iz svoje najjače države pored izgubljene.
            if let u = ulog, let n = s.najjacaPored(odakle, tim: napadaTim) { s.oblasti[n]!.vojske = max(1, s.oblasti[n]!.vojske - u) }
        }
        s.tacnih[napadaTim, default: 0] += napadac.tacnih
        s.tacnih[braniTim, default: 0] += branilac.tacnih
        s.primeniEfekte(napadac, tim: napadaTim, kuda: kuda, pobedio: pobedio)
        if !tvrdjavaDrzi { s.primeniEfekte(branilac, tim: braniTim, kuda: kuda, pobedio: !pobedio, brani: true) }
        // Kontranapad: odbrana sa 3+ tačna (država napadača je već preuzeta) daje napad više i +1 prednost odatle.
        if !pobedio && !tvrdjavaDrzi && branilac.tacnih >= Pravila.tacnihZaKontranapad {
            var k = s.kontranapad ?? [:]
            k[braniTim] = odakle
            s.kontranapad = k
        }
        // Opsada: drugi neuspeli napad zaredom na prestonicu daje braniocu kartu.
        if igraci.contains(where: { $0.prestonica == kuda && $0.tim == braniTim }) {
            var o = s.opsada ?? [:]
            if pobedio { o[kuda] = nil } else {
                o[kuda, default: 0] += 1
                if o[kuda]! >= Pravila.napadaZaOpsadu { s.dodeliKartu(braniTim); o[kuda] = 0 }
            }
            s.opsada = o
        }
        // Pobeda nad igračem (napad ili odbrana) donosi ratnu kartu.
        let pobednikBitke = pobedio ? napadaTim : braniTim
        s.zabeleziPobedu(napadaTim, pobedio)
        if !tvrdjavaDrzi { s.zabeleziPobedu(braniTim, !pobedio) }
        if !tvrdjavaDrzi {
            s.dodeliKartu(pobednikBitke)
            var p = s.pobedaBitaka ?? [:]
            p[pobednikBitke, default: 0] += 1
            s.pobedaBitaka = p
        }
        s.posleBitke()
        return (s, Ishod(gubitakNapadaca: gubitakNapadaca, gubitakBranioca: gubitakBranioca, osvojeno: pobedio, proboj: proboj, plen: plen,
                         izgubljenaDrzava: !pobedio && !tvrdjavaDrzi))
    }

    /// Niz pobeda (vlasnik 04.11): 3 dobijene bitke zaredom (napad ili odbrana, i preko poteza) daju ratnu kartu.
    mutating func zabeleziPobedu(_ tim: String, _ pobeda: Bool) {
        var z = pobedeZaredom ?? [:]
        z[tim] = pobeda ? (z[tim] ?? 0) + 1 : 0
        if (z[tim] ?? 0) >= Pravila.pobedaZaKartu { dodeliKartu(tim); z[tim] = 0 }
        pobedeZaredom = z
    }

    /// Moći vojske koje menjaju ishod bitke (vlasnik 04.11): Plen, Utvrđenje, Radionica, Garnizon, Špijunska mreža.
    mutating func primeniEfekte(_ skor: Skor, tim: String, kuda: String, pobedio: Bool, brani: Bool = false) {
        guard skor.efekti?.isEmpty == false else { return }
        if pobedio && !brani && skor.ima(.plen), oblasti[kuda]?.vlasnik == tim { oblasti[kuda]!.vojske += 1 }
        if pobedio && !brani && skor.ima(.utvrdjenje), oblasti[kuda]?.vlasnik == tim { var b = bedemi ?? [:]; b[kuda] = krug + 1; bedemi = b }
        if pobedio && brani && skor.ima(.garnizon), oblasti[kuda]?.vlasnik == tim { oblasti[kuda]!.vojske += 2 }
        if pobedio && skor.ima(.spijunskaMreza) {
            var sve = karteTimova ?? [:]
            if (sve[tim]?.count ?? 0) < Pravila.najviseKarata { sve[tim, default: []].append(.spijun); karteTimova = sve }
        }
        if skor.ima(.radionica), let p = igraci.first(where: { $0.tim == tim })?.prestonica, oblasti[p]?.vlasnik == tim {
            oblasti[p]!.vojske += min(3, skor.tacnih)
        }
    }

    /// Zlatna groznica: osvojena država u Severnoj Americi daje +1 vojsku.
    func groznica(_ kuda: String) -> Int { aktivanDogadjaj("sam") && Kontinenti.od(kuda).id == "sam" ? 1 : 0 }

    /// Karte za osvajanje: zatvoren region i proboj uvek, Izvidnica i za svako drugo osvajanje zaredom.
    mutating func nagradiOsvajanje(_ tim: String, kuda: String, proboj: Bool) {
        let region = Mapa.oblast(kuda).region
        let zatvoren = Mapa.oblasti.filter { $0.region == region && oblasti[$0.id] != nil }.allSatisfy { oblasti[$0.id]?.vlasnik == tim }
        if zatvoren { dodeliKartu(tim) }
        if proboj { dodeliKartu(tim) }
        // Dve osvojene države u jednom potezu: karta (treća je proboj, i on daje kartu).
        if niz == Pravila.osvajanjaZaKartu { dodeliKartu(tim) }
        if !zatvoren && !proboj && vojskaTima(tim) == .izvidnica && niz % 2 == 0 { dodeliKartu(tim) }
    }

    private mutating func posleBitke() {
        for i in igraci.indices where !igraci[i].ispao && !oblasti.values.contains(where: { $0.vlasnik == igraci[i].tim }) {
            igraci[i].ispao = true
        }
        bitaka += 1
        ulog = nil
        // Misija pobeđuje tek kad se drži ceo krug (do početka sledećeg poteza tog tima), vlasnik 04.11; zavrsiPotez proverava.
        oznaciIspunjeneMisije()
    }

    /// Marš, jednom po potezu: vojske do svoje države udaljene najviše 3 koraka kroz svoje države; u izvoru ostaje 1.
    func utvrdi(odakle: String, kuda: String, broj: Int) -> Stanje {
        let tim = trenutni.tim
        guard faza == .napad, !utvrdjeno, let a = oblasti[odakle], let b = oblasti[kuda],
              a.vlasnik == tim, b.vlasnik == tim, dometMarsa(odakle).contains(kuda) else { return self }
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
        if Set(igraci.filter { !$0.ispao }.map { strana($0.tim) }).count <= 1 { s.faza = .kraj; return s }
        // Kontranapad važi samo na prvom sledećem potezu tima.
        s.kontranapad?[trenutni.tim] = nil
        var sledeci = naPotezu
        var krug = self.krug
        repeat {
            sledeci = (sledeci + 1) % igraci.count
            if sledeci == 0 { krug += 1 }
        } while igraci[sledeci].ispao
        if krug > ukupnoKrugova { s.faza = .kraj; return s }
        s.naPotezu = sledeci; s.krug = krug; s.faza = .snabdevanje
        s.zaRaspored = 0; s.bitaka = 0; s.niz = 0; s.utvrdjeno = false
        if krug != self.krug { s.pokreniDogadjajAkoTreba() }
        s.oznaciIspunjeneMisije()
        // Tim koji je ispunio misiju i držao je ceo krug pobeđuje na početku svog poteza.
        let t = s.trenutni.tim
        if s.pobednik == nil, s.misijaOd?[t] != nil, s.napredakMisije(t) >= 1 { s.pobednik = t; s.faza = .kraj }
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

    /// Uslov bitke za metu; `za` = tim koji odgovara (Mudraci imaju više vremena), Karneval produžava sat u Južnoj Americi.
    func uslovBitke(_ kuda: String, za tim: String? = nil) -> Uslov {
        let o = odbranaMete(kuda)
        let dodatak = (tim.map { vojskaTima($0) == .mudraci } == true ? Pravila.sekundiMudraci : 0)
            + (tim.map { drziCudo($0, "AUS") } == true ? Pravila.sekundiOpera : 0)
            + (aktivanDogadjaj("jam") && Kontinenti.od(kuda).id == "jam" ? Pravila.sekundiKarneval : 0)
        return Uslov(sekundi: (o == .brzSat ? Pravila.sekundiBrzSat : Pravila.sekundiPoPitanju) + dodatak, bezPomoci: o == .bezPomoci,
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
        case "drzava60": return do1(Double(drzave.count) / prag(60))
        case "drzava45x2": return do1(Double(drzave.filter { (oblasti[$0.id]?.vojske ?? 0) >= 2 }.count) / prag(45))
        case "regiona8":
            return do1(Double(Mapa.regioni.filter { r in Mapa.oblasti.filter { $0.region == r.id }.allSatisfy { oblasti[$0.id]?.vlasnik == tim } }.count) / prag(8))
        case "prestonice2": return do1(Double(igraci.filter { $0.tim != tim && oblasti[$0.prestonica]?.vlasnik == tim }.count) / 2)
        case "izbaci":
            let meta = metaMisije[tim]
            return igraci.filter { $0.tim == meta }.allSatisfy(\.ispao) ? 1 : 0
        case "tacnih25": return do1(Double(tacnih[tim] ?? 0) / 25) * 0.5 + do1(Double(drzave.count) / 30) * 0.5
        case "evr-afr": return udeo(tim, ["evr", "afr"])
        case "sam-evr": return udeo(tim, ["sam", "evr"])
        case "azi-oke": return udeo(tim, ["azi", "oke"])
        case "afr-jam": return udeo(tim, ["afr", "jam"])
        case "kontinenta2":
            let udeli = Kontinenti.svi.map { udeo(tim, [$0.id]) }.sorted(by: >)
            return (udeli[0] + udeli[1]) / 2
        case "drzava50": return do1(Double(drzave.count) / prag(50))
        case "regiona10": return do1(Double(celiRegioni(tim)) / prag(10))
        case "regiona6-kontinent":
            return do1(Double(celiRegioni(tim)) / prag(6)) * 0.5 + (Kontinenti.svi.map { udeo(tim, [$0.id]) }.max() ?? 0) * 0.5
        case "prestonice3": return do1(Double(igraci.filter { $0.tim != tim && oblasti[$0.prestonica]?.vlasnik == tim }.count) / 3)
        case "vojske150": return do1(Double(drzave.reduce(0) { $0 + (oblasti[$1.id]?.vojske ?? 0) }) / prag(150))
        case "tacnih40": return do1(Double(tacnih[tim] ?? 0) / 40)
        case "pobeda10": return do1(Double(pobedaBitaka?[tim] ?? 0) / 10)
        case "ostrva": return udeoRegiona(tim, ["oke", "kar"])
        case "put-svile": return udeoRegiona(tim, ["bli", "caz", "iaz"])
        case "mediteran": return udeoRegiona(tim, ["jev", "saf", "bli"])
        case "svuda4":
            return Kontinenti.svi.map { k in do1(Double(Kontinenti.oblasti(k.id).filter { oblasti[$0]?.vlasnik == tim }.count) / 4) }.reduce(0, +)
                / Double(Kontinenti.svi.count)
        case "prestonica35":
            let svoja = igraci.contains { $0.tim == tim && oblasti[$0.prestonica]?.vlasnik == tim }
            return svoja ? do1(Double(drzave.count) / prag(35)) : 0
        case "amerike-pola": return udeo(tim, ["jam"]) * 0.5 + do1(udeo(tim, ["sam"]) * 2) * 0.5
        case "cuda3": return do1(Double(Cudo.sva.filter { oblasti[$0.oblast]?.vlasnik == tim }.count) / 3)
        case "pohodi3": return do1(Double(uspeliPohodi?[tim] ?? 0) / 3) * 0.6 + do1(Double(drzave.count) / 25) * 0.4
        case "evr-bli": return (udeo(tim, ["evr"]) + udeoRegiona(tim, ["bli"])) / 2
        case "sam-kar-jam": return udeoRegiona(tim, ["sam", "kar", "jam"])
        case "afr-bli": return (udeo(tim, ["afr"]) + udeoRegiona(tim, ["bli"])) / 2
        case "azi-ceo": return udeo(tim, ["azi"])
        case "afr-ceo": return udeo(tim, ["afr"]) * 0.7 + do1(Double(drzave.count) / prag(40)) * 0.3
        case "evr-ceo-prest": return udeo(tim, ["evr"]) * 0.8 + (tudjihPrestonica(tim) >= 1 ? 0.2 : 0)
        case "kontinenta3":
            let u = Kontinenti.svi.map { udeo(tim, [$0.id]) }.sorted(by: >)
            return (u[0] + u[1] + u[2]) / 3
        case "drzava70": return do1(Double(drzave.count) / prag(70))
        case "drzava40x3": return do1(Double(drzave.filter { (oblasti[$0.id]?.vojske ?? 0) >= 3 }.count) / prag(40))
        case "regiona12": return do1(Double(celiRegioni(tim)) / prag(12))
        case "vojske200": return do1(Double(drzave.reduce(0) { $0 + (oblasti[$1.id]?.vojske ?? 0) }) / prag(200))
        case "tacnih60": return do1(Double(tacnih[tim] ?? 0) / 60) * 0.5 + do1(Double(drzave.count) / prag(35)) * 0.5
        case "pobeda15": return do1(Double(pobedaBitaka?[tim] ?? 0) / 15)
        case "cuda4": return do1(Double(Cudo.sva.filter { oblasti[$0.oblast]?.vlasnik == tim }.count) / 4) * 0.6 + do1(Double(drzave.count) / prag(30)) * 0.4
        case "cuda-kontinent": return do1(Double(Cudo.sva.filter { oblasti[$0.oblast]?.vlasnik == tim }.count) / 2) * 0.5 + (Kontinenti.svi.map { udeo(tim, [$0.id]) }.max() ?? 0) * 0.5
        case "prestonice-svoja":
            let svoja = igraci.contains { $0.tim == tim && oblasti[$0.prestonica]?.vlasnik == tim }
            return svoja ? do1(Double(tudjihPrestonica(tim)) / 2) : 0
        case "svuda6":
            return Kontinenti.svi.map { k in do1(Double(Kontinenti.oblasti(k.id).filter { oblasti[$0]?.vlasnik == tim }.count) / Double(min(6, Kontinenti.oblasti(k.id).count))) }.reduce(0, +)
                / Double(Kontinenti.svi.count)
        case "severna-hem": return udeoRegiona(tim, ["sam", "sev", "zev"])
        case "juzna-hem": return udeoRegiona(tim, ["jam", "jaf", "oke"])
        case "indijski": return udeoRegiona(tim, ["iaf", "bli", "caz"])
        case "pacifik": return udeoRegiona(tim, ["iaz", "jia", "oke"])
        case "atlantik": return udeoRegiona(tim, ["zaf", "zev", "jam"])
        case "balkan-bli": return udeoRegiona(tim, ["jev", "iev", "bli"])
        case "crna-afrika": return udeoRegiona(tim, ["zaf", "caf", "jaf"])
        case "evroazija": return udeoRegiona(tim, ["iev", "caz", "iaz"])
        case "morske5": return do1(Double(Mapa.more.filter { oblasti[$0.a]?.vlasnik == tim && oblasti[$0.b]?.vlasnik == tim }.count) / 5)
        case "granica":
            return drzave.contains { (oblasti[$0.id]?.vojske ?? 0) < 2 } ? min(0.9, Double(drzave.count) / prag(25)) : do1(Double(drzave.count) / prag(25))
        case "regiona8-prest":
            let svoja = igraci.contains { $0.tim == tim && oblasti[$0.prestonica]?.vlasnik == tim }
            return svoja ? do1(Double(celiRegioni(tim)) / prag(8)) : 0
        case "pohodi4": return do1(Double(uspeliPohodi?[tim] ?? 0) / 4) * 0.6 + do1(Double(drzave.count) / prag(30)) * 0.4
        case "kontinent-svuda":
            let u = Kontinenti.svi.map { udeo(tim, [$0.id]) }
            guard let naj = u.indices.max(by: { u[$0] < u[$1] }) else { return 0 }
            let ostali = Kontinenti.svi.indices.filter { $0 != naj }.map { i in do1(Double(Kontinenti.oblasti(Kontinenti.svi[i].id).filter { oblasti[$0]?.vlasnik == tim }.count) / 3) }
            return u[naj] * 0.6 + (ostali.reduce(0, +) / Double(max(1, ostali.count))) * 0.4
        case "izbaci2":
            let ispali = Set(igraci.filter { $0.tim != tim && $0.ispao }.map(\.tim)).count
            return do1(Double(ispali) / 2)
        case "bez-poraza": return do1(Double(pobedaBitaka?[tim] ?? 0) / 8) * 0.5 + do1(Double(drzave.count) / prag(30)) * 0.5
        default: return 0
        }
    }

    /// Misije su pravljene za 3 strane; sa više strana mapa je podeljena na više delova, pa se pragovi
    /// država, regiona i vojski srazmerno smanjuju (6 strana = pola), najviše na pola.
    /// Vlasnik 04.11: na 12 igrača i 30 krugova „35 država” je padalo na 18 (prelako). Duga partija vraća pragove nazad:
    /// 12 krugova = puno smanjenje, 30 krugova = bez smanjenja.
    var faktorMisije: Double {
        let poStranama = min(1, max(0.5, 3 / Double(max(1, Set(igraci.map(\.tim)).count))))
        let duzina = min(1, max(0, Double(ukupnoKrugova - 12) / 18))
        return poStranama + (1 - poStranama) * duzina
    }
    func prag(_ n: Double) -> Double { max(1, (n * faktorMisije).rounded()) }

    /// Tekst misije sa brojevima prilagođenim broju strana (npr. „Drži 30 država” kad igra šestoro).
    func tekstMisije(_ id: String?) -> String {
        let t = Misije.tekst(id)
        guard let id, Misije.skalirane.contains(id) else { return t }
        var izlaz = t
        for m in t.matches(of: /\d+/).reversed() { izlaz.replaceSubrange(m.range, with: String(Int(prag(Double(t[m.range])!)))) }
        return izlaz
    }

    private func tudjihPrestonica(_ tim: String) -> Int { igraci.filter { $0.tim != tim && oblasti[$0.prestonica]?.vlasnik == tim }.count }

    private func celiRegioni(_ tim: String) -> Int {
        Mapa.regioni.filter { r in Mapa.oblasti.filter { $0.region == r.id }.allSatisfy { oblasti[$0.id]?.vlasnik == tim } }.count
    }

    private func udeoRegiona(_ tim: String, _ regioni: [String]) -> Double {
        let sve = Mapa.oblasti.filter { regioni.contains($0.region) }
        return Double(sve.filter { oblasti[$0.id]?.vlasnik == tim }.count) / Double(max(1, sve.count))
    }

    /// Upisuje krug u kom je tim ispunio misiju; tim koji je izgubi briše se (mora ponovo da je ispuni i drži).
    mutating func oznaciIspunjeneMisije() {
        var m = misijaOd ?? [:]
        for t in misije.keys {
            if napredakMisije(t) >= 1 { if m[t] == nil { m[t] = krug } } else { m[t] = nil }
        }
        misijaOd = m.isEmpty ? nil : m
    }

    var timSaIspunjenomMisijom: String? { misije.keys.sorted().first { napredakMisije($0) >= 1 } }

    /// Tajne misije: svaki tim svoju; misije iz `izbegni` (čovek ih je imao ove nedelje) idu na kraj reda.
    private mutating func dodeliMisije(_ slucajno: inout Slucajno, izbegni: Set<String> = []) {
        var timovi: [String] = []
        for p in igraci where !timovi.contains(p.tim) { timovi.append(p.tim) }
        let pojedinacno = timovi.count == igraci.count
        var ponuda = Misije.sve.filter { (pojedinacno || !$0.samoPojedinacno) && timovi.count - 1 >= $0.najmanjeRivala }.map(\.id)
        for i in stride(from: ponuda.count - 1, to: 0, by: -1) {
            let j = Int(slucajno.sledeci() * Double(i + 1))
            ponuda.swapAt(i, j)
        }
        ponuda = ponuda.filter { !izbegni.contains($0) } + ponuda.filter { izbegni.contains($0) }
        for (i, tim) in timovi.enumerated() {
            let m = ponuda[i % ponuda.count]
            misije[tim] = m
            if m == "izbaci" {
                let drugi = timovi.filter { $0 != tim && strana($0) != strana(tim) }
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

    /// Narav bota u ovoj partiji: iz id-a i semena partije (nova partija, nova narav); bez semena stara, stalna po id-ju.
    static func narav(_ id: String, seme: UInt32? = nil) -> Narav {
        guard let seme, seme != 0 else {
            switch id.unicodeScalars.reduce(0, { $0 + Int($1.value) }) % 3 { case 0: return .napadac; case 1: return .graditelj; default: return .oprezan }
        }
        switch Int(mesaj(id, seme) * 3) { case 0: return .napadac; case 1: return .graditelj; default: return .oprezan }
    }
    func narav(_ id: String) -> Narav { Stanje.narav(id, seme: seme) }

    /// Ljudi u partiji: igrač na ovom telefonu ili pravi nalog („u:”).
    private func jeCovek(_ i: Igrac) -> Bool { i.covek || i.id.hasPrefix("u:") }

    /// Snaga tima: države, vojske i celi regioni (bonus vojske svakog kruga).
    func snaga(_ tim: String) -> Double {
        let moje = oblasti.values.filter { $0.vlasnik == tim }
        return Double(moje.count) + Double(moje.reduce(0) { $0 + $1.vojske }) * 0.5 + Double(bonusRegiona(tim)) * 3
    }

    /// Koga bot cilja (vlasnik 03.11: svi ravnopravno, i ljudi i botovi): najjačeg suseda koji nije saveznik;
    /// kad nema suseda, najjačeg rivala na mapi. Zato se botovi kolju i međusobno.
    func ciljBota(_ tim: String) -> String? {
        let rivali = Set(igraci.filter { !$0.ispao && $0.tim != tim && !uSavezu(tim, $0.tim) }.map(\.tim))
        let moje = oblasti.filter { $0.value.vlasnik == tim }.keys
        let susedi = Set(moje.flatMap { Mapa.susedi($0) }.compactMap { oblasti[$0]?.vlasnik }).intersection(rivali)
        return (susedi.isEmpty ? rivali : susedi).max { (snaga($0), $0) < (snaga($1), $1) }
    }

    /// Koliko tuđe vojske preti državi (cilj se računa jače).
    func pretnja(_ id: String, tim: String, cilj: String?) -> Double {
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
    static func sansaBitke(_ a: Double, _ b: Double, n: Int, prednost: Bool, pomak: Int = 0) -> Double {
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
            let r = i - j + pomak
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
        if Cudo.za(kuda) != nil { v += 2.5 }
        if pohodi?[tim] == o.region { v += 1.5 }
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
            p = Stanje.sansaBitke(tacnostBota, branilac, n: uslovBitke(kuda).pitanja, prednost: odbranaMete(kuda) == .prednost,
                                  pomak: pomakBitke(odakle: odakle, kuda: kuda))
            gubitak = 1 + Double(max(0, izvor.vojske - Pravila.gubitakPorazenogNapadaca)) * 0.4
            if igraci.contains(where: { $0.tim == tim && $0.prestonica == odakle }) { gubitak += 4 }
            if fali(Mapa.oblast(odakle).region, tim: tim) == 0 { gubitak += Double(Mapa.regioni.first { $0.id == Mapa.oblast(odakle).region }?.bonus ?? 0) }
        } else {
            p = tacnostBota
            gubitak = izvor.vojske - 1 >= Pravila.vojskiBezGubitkaNaNeutralnoj ? 0 : 0.5
        }
        if nar == .oprezan { gubitak *= 1.3 }
        return p * dobitak - (1 - p) * gubitak
    }

    /// Prag ispod kog bot ne napada; slabija vojska u izvoru traži više.
    private func pragNapada(_ nar: Narav) -> Double {
        switch nar { case .napadac: 0.1; case .graditelj: 0.25; case .oprezan: 0.5 }
    }

    /// Koliko od najboljeg poteza bot još smatra dobrim (lako 1,2, normalno 0,6, teško 0,25 poena ocene).
    var rasipanjeBota: Double { tacnostBota < 0.55 ? 1.2 : tacnostBota < 0.7 ? 0.6 : 0.25 }

    /// Koliko često bot uzme lošiji potez (lako 35%, normalno 12%, teško nikad).
    private var greskaBota: Double { tacnostBota < 0.55 ? 0.35 : tacnostBota < 0.7 ? 0.12 : 0 }

    func botRasporedi() -> Stanje {
        var s = self
        let tim = trenutni.tim
        let cilj = ciljBota(tim)
        while s.faza == .raspored {
            let snabdevene = s.snabdevene(tim)
            let moje = s.oblastiIgraca(s.trenutni.id).filter { snabdevene.contains($0) }
            guard let prva = moje.first else { s.zaRaspored = 0; s.faza = .napad; break }
            // Vojska ide tamo gde je najveća pretnja ili odakle se zatvara region; prestonica se čuva.
            func ocena(_ id: String) -> Double {
                var v = s.pretnja(id, tim: tim, cilj: cilj) - Double(s.oblasti[id]?.vojske ?? 0) * 0.6
                if Mapa.susedi(id).contains(where: { n in s.oblasti[n] != nil && s.oblasti[n]?.vlasnik != tim && s.fali(Mapa.oblast(n).region, tim: tim) == 1 }) { v += 3 }
                if s.igraci.contains(where: { $0.tim == tim && $0.prestonica == id }) { v += 1.5 }
                // Šum iz semena partije: raspored nije svake partije isti.
                if let seme = s.seme { v += Stanje.mesaj(id, seme, s.krug * 31 + s.zaRaspored) * s.rasipanjeBota * 2 }
                return v
            }
            let granica = moje.filter { s.pretnja($0, tim: tim, cilj: cilj) > 0 }
            let cel = (granica.isEmpty ? moje : granica).max { ocena($0) < ocena($1) } ?? prva
            s = s.rasporedi(cel)
        }
        return s
    }

    func botSledeciNapad() -> (odakle: String, kuda: String)? {
        let nar = narav(trenutni.id)
        var opcije: [(String, String, Double)] = []
        for odakle in oblastiIgraca(trenutni.id) {
            for kuda in mete(odakle) { opcije.append((odakle, kuda, ocenaNapada(odakle: odakle, kuda: kuda))) }
        }
        guard !opcije.isEmpty else { return nil }
        // Šum je vezan za krug, bitku i seme partije: isti na dva telefona, različit od partije do partije.
        var r = Slucajno(seme: UInt32(truncatingIfNeeded: krug * 7919 + naPotezu * 131 + bitaka * 17 + 1) ^ (seme ?? 0))
        if r.sledeci() < greskaBota {
            let losije = opcije.filter { $0.2 > -1 }
            if !losije.isEmpty { let o = losije[Int(r.sledeci() * Double(losije.count))]; return (o.0, o.1) }
        }
        guard let najbolja = opcije.max(by: { $0.2 < $1.2 }), najbolja.2 >= pragNapada(nar) else { return nil }
        // Vlasnik 03.11: ne uvek isti potez — bot bira među skoro najboljim (lako šire, teško uže), težinski po oceni.
        let dobri = opcije.filter { $0.2 >= max(pragNapada(nar), najbolja.2 - rasipanjeBota) }
        let tezine = dobri.map { $0.2 - (najbolja.2 - rasipanjeBota) + 0.05 }
        var x = r.sledeci() * tezine.reduce(0, +)
        for (o, t) in zip(dobri, tezine) { x -= t; if x <= 0 { return (o.0, o.1) } }
        return (najbolja.0, najbolja.1)
    }

    /// Savet igraču („Šta da radim?”, vlasnik 04.11): najbolji napad po istom mozgu kao bot, bez šuma i bez praga naravi.
    func najboljiNapad() -> (odakle: String, kuda: String, ocena: Double)? {
        var najbolji: (String, String, Double)?
        for odakle in oblastiIgraca(trenutni.id) {
            for kuda in mete(odakle) {
                let o = ocenaNapada(odakle: odakle, kuda: kuda)
                if najbolji == nil || o > najbolji!.2 { najbolji = (odakle, kuda, o) }
            }
        }
        return najbolji.map { ($0.0, $0.1, $0.2) }
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
