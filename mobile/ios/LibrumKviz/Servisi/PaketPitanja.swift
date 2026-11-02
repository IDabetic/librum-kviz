import Foundation

struct Pitanje: Codable, Identifiable, Equatable {
    let id: String
    let question_text: String
    let options: [String]
    let correct_answer: Int
    var genre: String? = nil
    /// Slika uz pitanje (kviz Slikari) i opis dela posle odgovora.
    var slika: String? = nil
    var opis: String? = nil
}

/// Fond pitanja po igri (RPC aplikacija_pitanja): opšti za PRO, Brzi, Duel i Osvajanje, Book za književnost.
enum Fond: String { case opste, book, slikari }

/// Pitanje spremno za prikaz: ponude promešane, zna se koja je tačna.
struct Prikaz: Equatable {
    let tekst: String
    let opcije: [String]
    let tacan: Int
    var zanr: String? = nil
    var slika: URL? = nil
    var opis: String? = nil

    init(_ p: Pitanje) {
        let red = [0, 1, 2, 3].shuffled()
        tekst = p.question_text
        zanr = p.genre.flatMap { $0 == "Razno" ? nil : $0 }
        slika = p.slika.flatMap(URL.init(string:))
        opis = p.opis
        opcije = red.map { p.options[$0] }
        tacan = red.firstIndex(of: p.correct_answer) ?? 0
    }
}

/// Paket pitanja iz RPC `osvajanje_pitanja`, keširan na disku. Bez mreže igra
/// ide iz poslednjeg paketa; tako jedna partija troši jedan mali zahtev.
actor PaketPitanja {
    static let deljeni = PaketPitanja()
    private let velicina = 60

    private func fajl(_ fond: Fond) -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Opšti fond zadržava staro ime fajla, da postojeći keš i dalje važi.
        return folder.appendingPathComponent(fond == .opste ? "paket-pitanja.json" : "paket-\(fond.rawValue).json")
    }

    /// Svež paket ako mreža radi, inače keš, inače rezerva ugrađena u aplikaciju.
    func ucitaj(_ fond: Fond = .opste) async throws -> [Pitanje] {
        if let svez: [Pitanje] = try? await Supabase.deljeni.rpc("aplikacija_pitanja", ["p_igra": fond.rawValue, "p_broj": velicina]) {
            let ispravna = svez.filter { $0.options.count == 4 && (0..<4).contains($0.correct_answer) }
            if !ispravna.isEmpty {
                try? JSONEncoder().encode(ispravna).write(to: fajl(fond), options: .atomic)
                return ispravna.shuffled()
            }
        }
        if let d = try? Data(contentsOf: fajl(fond)), let kes = try? JSONDecoder().decode([Pitanje].self, from: d), !kes.isEmpty {
            return kes.shuffled()
        }
        let url = fond == .opste
            ? Bundle.main.url(forResource: "rezervna-pitanja", withExtension: "json")
            : Bundle.main.url(forResource: "rezerva-book", withExtension: "json", subdirectory: "igre")
        if let url,
           let d = try? Data(contentsOf: url),
           let redovi = try? JSONSerialization.jsonObject(with: d) as? [[Any]] {
            let rezerva = redovi.enumerated().compactMap { i, r -> Pitanje? in
                guard r.count >= 3, let t = r[0] as? String, let o = r[1] as? [String], let c = r[2] as? Int else { return nil }
                return Pitanje(id: "r\(i)", question_text: t, options: o, correct_answer: c, genre: r.count > 3 ? r[3] as? String : nil)
            }
            if !rezerva.isEmpty { return rezerva.shuffled() }
        }
        throw Supabase.Greska(poruka: "Pitanja nisu stigla. Proveri internet i pokušaj ponovo.")
    }

    /// Kviz po temi (RPC aplikacija_kviz): 10 pitanja iz fonda, žanra ili samo teških.
    /// Bez mreže bira iz keša/rezerve istog fonda.
    func kviz(_ fond: Fond, zanr: String? = nil, tesko: Bool = false, broj: Int = 10) async throws -> [Pitanje] {
        if fond == .slikari { return try Self.slikari(broj: broj, tesko: tesko) }
        var parametri: [String: Any] = ["p_fond": fond.rawValue, "p_broj": broj]
        if let zanr { parametri["p_zanr"] = zanr }
        if tesko { parametri["p_tezina"] = "tesko" }
        if let svez: [Pitanje] = try? await Supabase.deljeni.rpc("aplikacija_kviz", parametri) {
            let ispravna = svez.filter { $0.options.count == 4 && (0..<4).contains($0.correct_answer) }
            if ispravna.count >= min(broj, 5) { return ispravna }
        }
        let rezerva = try await ucitaj(fond).filter { zanr == nil || $0.genre == zanr }
        guard !rezerva.isEmpty else { throw Supabase.Greska(poruka: "Za ovu temu nema sačuvanih pitanja. Poveži se na internet i pokušaj ponovo.") }
        return Array(rezerva.prefix(broj))
    }

    /// Slikari iz ugrađenog paketa (src/lib/igre/slikari.json, alati/slikari-u-json.py): pet lakih/srednjih
    /// i ostatak bilo kog nivoa, da prvi kviz ne bude samo nepoznata dela; „teško” uzima samo teška.
    static func slikari(broj: Int, tesko: Bool) throws -> [Pitanje] {
        struct Delo: Decodable { let id, naziv, slika: String; let ponude: [String]; let godina, pravac, muzej, tezina: String }
        guard let url = Bundle.main.url(forResource: "slikari", withExtension: "json", subdirectory: "igre"),
              let d = try? Data(contentsOf: url), let dela = try? JSONDecoder().decode([Delo].self, from: d), !dela.isEmpty else {
            throw Supabase.Greska(poruka: "Paket slika nije pronađen u aplikaciji.")
        }
        let izbor: [Delo]
        if tesko {
            izbor = Array(dela.filter { $0.tezina == "teško" }.shuffled().prefix(broj))
        } else {
            let lakse = dela.filter { $0.tezina != "teško" }.shuffled().prefix(broj / 2)
            let ostalo = dela.filter { d in !lakse.contains { $0.id == d.id } }.shuffled().prefix(broj - lakse.count)
            izbor = (Array(lakse) + Array(ostalo)).shuffled()
        }
        return izbor.map { d -> Pitanje in
            // Delo bez slike je tekstualno pitanje: godina pomaže da naziv ne bude jedini trag.
            let imaSliku = !d.slika.isEmpty
            let godina = d.godina.isEmpty ? "" : " (\(d.godina))"
            return Pitanje(id: d.id, question_text: imaSliku ? "Ko je naslikao delo „\(d.naziv)”?" : "Ko je naslikao delo „\(d.naziv)”\(godina)?",
                           options: d.ponude, correct_answer: 0, genre: d.pravac, slika: imaSliku ? d.slika : nil,
                           opis: ([d.naziv, d.godina, d.muzej] + (imaSliku ? ["Slika: Wikimedia Commons"] : [])).filter { !$0.isEmpty }.joined(separator: " · "))
        }
    }

    /// Reči za vešanje (RPC aplikacija_reci), sa istim redom rezervi.
    func reci() async throws -> [Rec] {
        let fajl = fajl(.opste).deletingLastPathComponent().appendingPathComponent("paket-reci.json")
        if let svez: [Rec] = try? await Supabase.deljeni.rpc("aplikacija_reci", ["p_broj": 40]), !svez.isEmpty {
            try? JSONEncoder().encode(svez).write(to: fajl, options: .atomic)
            return svez.shuffled()
        }
        if let d = try? Data(contentsOf: fajl), let kes = try? JSONDecoder().decode([Rec].self, from: d), !kes.isEmpty { return kes.shuffled() }
        if let url = Bundle.main.url(forResource: "rezerva-reci", withExtension: "json", subdirectory: "igre"),
           let d = try? Data(contentsOf: url), let redovi = try? JSONSerialization.jsonObject(with: d) as? [[String]] {
            return redovi.enumerated().compactMap { i, r in r.count == 3 ? Rec(id: "r\(i)", word: r[0], hint: r[1], category: r[2]) : nil }.shuffled()
        }
        throw Supabase.Greska(poruka: "Reči nisu stigle. Proveri internet i pokušaj ponovo.")
    }
}

struct Rec: Codable, Equatable { let id: String; let word: String; let hint: String?; let category: String? }

/// Špil koji se vrti u krug kad se pitanja potroše.
struct Spil {
    private var pitanja: [Pitanje]
    private var indeks = 0
    init(_ pitanja: [Pitanje]) { self.pitanja = pitanja }
    mutating func sledece() -> Prikaz {
        let p = pitanja[indeks % pitanja.count]
        indeks += 1
        return Prikaz(p)
    }
}
