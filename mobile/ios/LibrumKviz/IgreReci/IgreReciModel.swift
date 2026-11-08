import SwiftUI

/// Šest dnevnih igara reči (scripts/2026-11-08_igre-reci.sql, zagonetke iz alati/igre_reci.py).
/// Ista zagonetka za sve igrače po beogradskom danu; rang listu ocenjuje server.
enum IgraReci: String, CaseIterable, Identifiable, Codable {
    case premetaljka, petSlova = "pet_slova", lanac, sifra, ukrstenica, zmija

    var id: String { rawValue }

    var naslov: String {
        switch self {
        case .premetaljka: "Premetaljka"
        case .petSlova: "Pet slova"
        case .lanac: "Lanac"
        case .sifra: "Šifra"
        case .ukrstenica: "Mini ukrštenica"
        case .zmija: "Zmija"
        }
    }

    var opis: String {
        switch self {
        case .premetaljka: "Složi reči od 7 slova"
        case .petSlova: "Pogodi reč u 6 pokušaja"
        case .lanac: "Menjaj po jedno slovo"
        case .sifra: "Svaki broj je jedno slovo"
        case .ukrstenica: "Mala ukrštenica sa opisima"
        case .zmija: "Pronađi reči teme dana"
        }
    }

    var pravilo: String {
        switch self {
        case .premetaljka: "Dodiruj slova i složi reč od najmanje 3 slova. Glavna reč koristi svih 7."
        case .petSlova: "Zeleno: slovo je na mestu. Žuto: slovo je u reči, ali na drugom mestu. Sivo: nema ga."
        case .lanac: "Od prve do poslednje reči menjaj tačno jedno slovo; svaki korak mora biti prava reč."
        case .sifra: "Isti broj je uvek isto slovo. Dodirni polje, pa izaberi slovo."
        case .ukrstenica: "Dodirni polje, pročitaj opis i upiši reč. Drugi dodir menja smer."
        case .zmija: "Prevuci prstom preko susednih slova (gore, dole, levo, desno). Reči teme popunjavaju celu mrežu."
        }
    }

    var ikonica: String {
        switch self {
        case .premetaljka: "circle.hexagongrid.fill"
        case .petSlova: "square.grid.3x3.fill"
        case .lanac: "link"
        case .sifra: "number.square.fill"
        case .ukrstenica: "squareshape.split.3x3"
        case .zmija: "scribble.variable"
        }
    }

    var boja: Color {
        switch self {
        case .premetaljka: .zuta
        case .petSlova: .teal
        case .lanac: .narandzasta
        case .sifra: .ljubicasta
        case .ukrstenica: .nebo
        case .zmija: .roze
        }
    }
}

// MARK: Zagonetke

struct PremetaljkaZ: Codable { let slova: [String]; let glavna: String; let reci: [String] }
struct PetSlovaZ: Codable { let rec: String; var tezina: String? = nil }
struct LanacZ: Codable {
    let od: String; let doReci: String; let primer: [String]; let najmanje: Int
    enum CodingKeys: String, CodingKey { case od, doReci = "do", primer, najmanje }
}
struct SifraZ: Codable { let sirina, visina: Int; let polja: [[Int]]; let kljuc: [String: String]; let data: [Int]; let reci: [String]? }
struct UkrstenicaZ: Codable {
    struct Rec: Codable, Hashable { let rec: String; let x, y: Int; let smer: String; let broj: Int; let opis: String }
    let sirina, visina: Int; let reci: [Rec]
}
struct ZmijaZ: Codable {
    struct Rec: Codable, Hashable { let rec: String; let put: [[Int]] }
    let tema: String; let sirina, visina: Int; let slova: [String]; let reci: [Rec]
}

struct ZagonetkeDana: Codable {
    let premetaljka: PremetaljkaZ?
    let petSlova: PetSlovaZ?
    let lanac: LanacZ?
    let sifra: SifraZ?
    let ukrstenica: UkrstenicaZ?
    let zmija: ZmijaZ?
    enum CodingKeys: String, CodingKey { case premetaljka, petSlova = "pet_slova", lanac, sifra, ukrstenica, zmija }
}

struct MojRezultatReci: Codable, Hashable { let resio: Bool; let poeni, sekundi: Int; let pomoci: Int? }
struct DanReci: Codable {
    let datum: String
    let igre: ZagonetkeDana
    var moji: [String: MojRezultatReci]
    var nizovi: [String: Int]?
}
struct IshodReci: Codable, Hashable { let resio: Bool; let poeni, sekundi, mesto, ukupno: Int }
struct RedRangaReci: Decodable, Identifiable, Hashable {
    let mesto: Int; let id: String; let ime: String; let avatar: String?; let resio: Bool; let poeni, sekundi: Int
}

// MARK: Servis

/// Dan sa zagonetkama, napredak partija na telefonu i slanje rezultata.
@Observable @MainActor
final class IgreReci {
    static let deljeno = IgreReci()
    private(set) var dan: Ucitano<DanReci> = .ucitava
    private static let kljucDana = "igreReci.dan"

    private init() {
        // poslednji dan iz keša: igra radi i bez mreže dok je isti datum
        if let d = UserDefaults.standard.data(forKey: Self.kljucDana), let s = try? JSONDecoder().decode(DanReci.self, from: d),
           s.datum == Self.danas { dan = .gotovo(s) }
    }

    /// Današnji datum po Beogradu, isti kao igre_reci_danas() na serveru. Primer: "2026-11-09".
    static var danas: String {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Belgrade") ?? .current
        let c = k.dateComponents([.year, .month, .day], from: .now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func ucitaj(_ sesija: Sesija) async {
        do {
            let token = try? await sesija.vazeciToken()
            let d: DanReci = try await Supabase.deljeni.rpc("igre_reci_dan", [:], token: token)
            dan = .gotovo(d)
            if let podaci = try? JSONEncoder().encode(d) { UserDefaults.standard.set(podaci, forKey: Self.kljucDana) }
        } catch {
            if case .gotovo(let d) = dan, d.datum == Self.danas { return }
            dan = .greska(error.localizedDescription)
        }
    }

    func moj(_ igra: IgraReci) -> MojRezultatReci? {
        if case .gotovo(let d) = dan { return d.moji[igra.rawValue] }
        return nil
    }

    /// Rezultat već upisan na serveru, za ponovo otvorenu završenu igru (mesto se ne prikazuje).
    func upisano(_ igra: IgraReci) -> Ucitano<IshodReci?> {
        guard let m = moj(igra) else { return .gotovo(nil) }
        return .gotovo(IshodReci(resio: m.resio, poeni: m.poeni, sekundi: m.sekundi, mesto: 0, ukupno: 0))
    }

    func niz(_ igra: IgraReci) -> Int {
        if case .gotovo(let d) = dan { return d.nizovi?[igra.rawValue] ?? 0 }
        return 0
    }

    /// Šalje prvi rezultat dana (ponovljena igra se ne broji) i pamti ga u danu. Gost dobija nil.
    func zavrsi(_ igra: IgraReci, odgovor: [String: Any], resio: Bool, sekundi: Int, pomoci: Int, sesija: Sesija, napredak: Napredak) async throws -> IshodReci? {
        guard case .gotovo(var d) = dan else { return nil }
        _ = napredak.zabeleziIgru(kviz: "reci_" + igra.rawValue, tacnih: resio ? 1 : 0, netacnih: resio ? 0 : 1, pobeda: resio)
        guard sesija.prijavljen, let token = try? await sesija.vazeciToken() else { return nil }
        let ishod: IshodReci = try await Supabase.deljeni.rpc("igre_reci_zavrsi", [
            "p_igra": igra.rawValue, "p_datum": d.datum, "p_odgovor": odgovor, "p_sekundi": sekundi, "p_pomoci": pomoci,
        ], token: token)
        d.moji[igra.rawValue] = MojRezultatReci(resio: ishod.resio, poeni: ishod.poeni, sekundi: ishod.sekundi, pomoci: pomoci)
        dan = .gotovo(d)
        return ishod
    }

    func rang(_ igra: IgraReci) async -> [RedRangaReci] {
        (try? await Supabase.deljeni.rpc("igre_reci_rang", ["p_igra": igra.rawValue], token: nil)) ?? []
    }

    // MARK: napredak partije na telefonu (izlazak i povratak ne gube igru)

    static func ucitajPartiju<T: Decodable>(_ igra: IgraReci, datum: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: "igreReci.\(igra.rawValue).\(datum)") else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    static func sacuvajPartiju<T: Encodable>(_ igra: IgraReci, datum: String, _ stanje: T) {
        if let d = try? JSONEncoder().encode(stanje) { UserDefaults.standard.set(d, forKey: "igreReci.\(igra.rawValue).\(datum)") }
    }
}

/// Rečnik za proveru unosa (alati/igre_reci.py recnik → src/lib/igre/reci.txt, ~107 hiljada oblika).
enum RecnikReci {
    static let reci: Set<String> = {
        guard let url = Bundle.main.url(forResource: "reci", withExtension: "txt", subdirectory: "igre"),
              let tekst = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Set(tekst.split(separator: "\n").map(String.init))
    }()

    /// Primer: postoji("kuća") → true.
    static func postoji(_ rec: String) -> Bool { reci.contains(rec.lowercased()) }
}

/// Azbuka igara (latinica bez dvoslova; lj, nj i dž se slažu od dva slova, kao u Vešanju).
enum AzbukaReci {
    static let dozvoljena: Set<String> = Set("ABCČĆDĐEFGHIJKLMNOPRSŠTUVZŽ".map(String.init))

    /// Reč u niz slova. Primer: slova("kuća") → ["K", "U", "Ć", "A"].
    static func slova(_ rec: String) -> [String] { rec.uppercased().map(String.init) }

    /// Sekunde kao 1:05.
    static func vreme(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
