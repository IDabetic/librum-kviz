import Foundation

/// Takmičenje (vlasnik 03.11.2026): PRO, Book, Slikari, Brzi kviz i Vešanje za 2–8 igrača, svako za sebe ili timovi po dvoje,
/// protiv računara, pravih igrača ili mešano. Svi igraju isti sadržaj (domaćin ga šalje u sobu), svako na svom telefonu,
/// a rezultat ide na server posle svakog odgovora. Server: scripts/2026-11-03_takmicenja.sql.
enum IgraTakmicenja: String, CaseIterable, Identifiable {
    case pro, book, slikari, brzi, vesanje
    var id: String { rawValue }

    var naziv: String {
        switch self {
        case .pro: "PRO kviz"
        case .book: "Book kviz"
        case .slikari: "Slikari"
        case .brzi: "Brzi kviz"
        case .vesanje: "Vešanje"
        }
    }

    var opis: String {
        switch self {
        case .pro: "10 pitanja iz svega, brži odgovor nosi više"
        case .book: "10 pitanja iz književnosti"
        case .slikari: "10 dela: ko je naslikao?"
        case .brzi: "60 sekundi, tačno ili netačno"
        case .vesanje: "5 reči, ko pogodi više slova"
        }
    }

    var slika: String { "Igra_\(rawValue)" }

    /// Koliko stavki domaćin šalje u sobu: pitanja, tvrdnje (Brzi troši mnogo) ili reči.
    var broj: Int { self == .brzi ? 60 : self == .vesanje ? 5 : Takmicenje.pitanja }
}

enum Takmicenje {
    static let pitanja = 10
    static let sekundiPitanja = 20
    /// Pauza posle odgovora dok kartica pokazuje tačan (PitanjeKartica čeka 3 s); botovi je poštuju da bi tempo bio isti.
    static let pauzaOtkrivanja = 3.0
    static let osvezavanje: Duration = .seconds(1.5)

    /// Tačan odgovor: 10 poena plus do 10 za brzinu (svake 2 sekunde manje = 1 poen); netačan 0.
    /// Primer: `poeni(tacno: true, ms: 4_000)` = 18.
    static func poeni(tacno: Bool, ms: Int) -> Int {
        guard tacno else { return 0 }
        return 10 + max(0, (sekundiPitanja * 1000 - ms) / 2000)
    }

    struct Mesto: Decodable, Equatable, Identifiable {
        let mesto: Int
        let user_id: String?
        let bot: String?
        let pozvan: Bool
        let tim: Int
        let nadimak: String?
        let avatar: String?
        var poeni: Int
        var tacnih: Int
        var odigrano: Int
        var ms: Int
        var gotov: Bool
        var id: Int { mesto }
        var prazno: Bool { user_id == nil && bot == nil }
    }

    struct Soba: Decodable, Equatable {
        let id: String
        let kod: String
        let igra: String
        let domacin: String
        let velicina: Int
        let nacin: String
        let protivnici: String
        let tezina: String
        let seme: Int64
        let broj: Int
        var status: String
        var mesta: [Mesto]
        var vrsta: IgraTakmicenja { IgraTakmicenja(rawValue: igra) ?? .pro }
        var timovi: Bool { nacin == "timovi" }
    }

    struct Poziv: Decodable, Identifiable, Equatable {
        let kod: String; let igra: String; let velicina: Int; let nacin: String; let od: String; let avatar: String?
        var id: String { kod }
        var naziv: String { IgraTakmicenja(rawValue: igra)?.naziv ?? "Kviz" }
    }

    /// Red tabele uživo: pravi igrač sa servera, bot izračunat iz semena (isto na svakom telefonu).
    struct Rezultat: Identifiable, Equatable {
        let mesto: Int
        let ime: String
        let avatar: String?
        let tim: Int
        let poeni: Int
        let tacnih: Int
        let odigrano: Int
        let gotov: Bool
        let bot: Bool
        let ja: Bool
        var id: Int { mesto }
    }

    static func tabela(_ s: Soba, ja: String?, proteklo: Double) -> [Rezultat] {
        s.mesta.filter { !$0.prazno }.map { m in
            if let ime = m.bot {
                let b = Bot.rezultat(igra: s.vrsta, tezina: s.tezina, seme: s.seme, mesto: m.mesto, broj: s.broj, proteklo: proteklo)
                return Rezultat(mesto: m.mesto, ime: ime, avatar: nil, tim: m.tim, poeni: b.poeni, tacnih: b.tacnih, odigrano: b.odigrano,
                                gotov: b.gotov, bot: true, ja: false)
            }
            return Rezultat(mesto: m.mesto, ime: m.nadimak ?? "Igrač", avatar: m.avatar, tim: m.tim, poeni: m.poeni, tacnih: m.tacnih,
                            odigrano: m.odigrano, gotov: m.gotov || s.status == "kraj", bot: false, ja: m.user_id == ja)
        }
        .sorted { ($0.poeni, $0.tacnih, -$0.mesto) > ($1.poeni, $1.tacnih, -$1.mesto) }
    }

    /// Zbir po timu, najbolji prvi.
    static func timovi(_ r: [Rezultat]) -> [(tim: Int, poeni: Int, clanovi: [Rezultat])] {
        Dictionary(grouping: r, by: \.tim).map { (tim: $0.key, poeni: $0.value.reduce(0) { $0 + $1.poeni }, clanovi: $0.value) }
            .sorted { ($0.poeni, -$0.tim) > ($1.poeni, -$1.tim) }
    }

    static func imeTima(_ t: Int) -> String { "Tim " + String(UnicodeScalar(65 + t)!) }

    /// Seme za stavku i (Brzi: koja tvrdnja nudi tačan odgovor) — isto za sve u sobi.
    static func slucajno(_ seme: Int64, _ dodatak: Int) -> Slucajno {
        Slucajno(seme: UInt32(truncatingIfNeeded: seme) ^ UInt32(truncatingIfNeeded: dodatak &* 0x9E37_79B1))
    }

    /// Botovi: tempo i tačnost po težini, iz semena sobe i mesta. Telefon ih računa iz proteklog vremena,
    /// pa svi u sobi vide iste brojeve bez servera.
    enum Bot {
        struct Stanje: Equatable { var poeni = 0; var tacnih = 0; var odigrano = 0; var gotov = false }

        static func tacnost(_ tezina: String) -> Double { tezina == "lako" ? 0.5 : tezina == "tesko" ? 0.84 : 0.68 }
        /// Sekunde po odgovoru: (najmanje, raspon).
        static func tempo(_ tezina: String) -> (Double, Double) { tezina == "lako" ? (8, 9) : tezina == "tesko" ? (3.5, 5) : (5.5, 7) }

        static func rezultat(igra: IgraTakmicenja, tezina: String, seme: Int64, mesto: Int, broj: Int, proteklo: Double) -> Stanje {
            var r = Takmicenje.slucajno(seme, 7919 &* (mesto + 1))
            var s = Stanje()
            var vreme = 0.0
            let p = tacnost(tezina)
            switch igra {
            case .brzi:
                var b = BrziKviz()
                // Tvrdnja: botu treba 1,2–3,5 s (teško brže); pogodak po tačnosti, jer je tačno/netačno lakše od 4 ponude.
                let brzina = tezina == "lako" ? 3.5 : tezina == "tesko" ? 1.4 : 2.2
                while true {
                    vreme += brzina + r.sledeci() * 1.4
                    if vreme > Double(BrziKviz.sekundiRunde) { s.gotov = true; break }
                    if vreme > proteklo { break }
                    let pogodak = r.sledeci() < min(0.95, p + 0.1)
                    _ = b.odgovor(Self.izjava, kaze: pogodak, zavrsnica: vreme > Double(BrziKviz.sekundiRunde - BrziKviz.sekundiZavrsnice))
                    s.odigrano += 1
                }
                s.poeni = b.poeni; s.tacnih = b.tacnih
            case .vesanje:
                for _ in 0..<broj {
                    vreme += 14 + r.sledeci() * (tezina == "tesko" ? 14 : 26)
                    let pogodio = r.sledeci() < p
                    let poena = pogodio ? 30 + Int(r.sledeci() * 45) : Int(r.sledeci() * 12)
                    if vreme > proteklo { return s }
                    s.odigrano += 1; s.poeni += poena; if pogodio { s.tacnih += 1 }
                }
                s.gotov = true
            case .pro, .book, .slikari:
                let (najmanje, raspon) = tempo(tezina)
                for _ in 0..<broj {
                    let sekundi = min(Double(Takmicenje.sekundiPitanja), najmanje + r.sledeci() * raspon)
                    let tacno = r.sledeci() < p
                    vreme += sekundi
                    if vreme > proteklo { return s }
                    vreme += Takmicenje.pauzaOtkrivanja
                    s.odigrano += 1; s.poeni += Takmicenje.poeni(tacno: tacno, ms: Int(sekundi * 1000)); if tacno { s.tacnih += 1 }
                }
                s.gotov = true
            }
            return s
        }

        /// Tvrdnja koja je uvek tačna: bot „kaže tačno” kad pogađa, pa BrziKviz broji poene i množilac kao kod igrača.
        private static let izjava = BrziKviz.Izjava(Pitanje(id: "", question_text: "", options: ["a", "b"], correct_answer: 0), nasumicno: { 0 })
    }

    // MARK: Server

    private static func token() async throws -> String {
        guard let t = try await Sesija.trenutna?.vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se da bi igrao sa drugima.") }
        return t
    }

    /// Sadržaj kao JSON niz za server (pitanja ili reči, cela, da svi igraju isto).
    static func json<T: Encodable>(_ x: [T]) -> Any { (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(x))) ?? [] }

    static func napravi(igra: IgraTakmicenja, velicina: Int, timovi: Bool, protivnici: String, tezina: String, sadrzaj: Any, pozovi: [String]) async throws -> Soba {
        try await Supabase.deljeni.rpc("takmicenje_napravi", [
            "p_igra": igra.rawValue, "p_velicina": velicina, "p_nacin": timovi ? "timovi" : "svako", "p_protivnici": protivnici,
            "p_tezina": tezina, "p_sadrzaj": sadrzaj, "p_pozovi": pozovi,
        ], token: try await token())
    }

    static func udji(_ kod: String) async throws -> Soba { try await Supabase.deljeni.rpc("takmicenje_udji", ["p_kod": kod], token: try await token()) }
    static func stanje(_ id: String) async throws -> Soba { try await Supabase.deljeni.rpc("takmicenje_stanje", ["p_id": id], token: try await token()) }
    static func pokreni(_ id: String) async throws -> Soba { try await Supabase.deljeni.rpc("takmicenje_pokreni", ["p_id": id], token: try await token()) }

    static func rezultat(_ id: String, poeni: Int, tacnih: Int, odigrano: Int, ms: Int, gotov: Bool) async throws -> Soba {
        try await Supabase.deljeni.rpc("takmicenje_rezultat", ["p_id": id, "p_poeni": poeni, "p_tacnih": tacnih, "p_odigrano": odigrano,
                                                                "p_ms": ms, "p_gotov": gotov], token: try await token())
    }

    static func izadji(_ id: String) async {
        guard let t = try? await token() else { return }
        _ = try? await Supabase.deljeni.zahtev("rest/v1/rpc/takmicenje_izadji", metod: "POST", telo: ["p_id": id], token: t)
    }

    static func odbij(_ kod: String) async {
        guard let t = try? await token() else { return }
        _ = try? await Supabase.deljeni.zahtev("rest/v1/rpc/takmicenje_odbij", metod: "POST", telo: ["p_kod": kod], token: t)
    }

    static func pozivi() async -> [Poziv] {
        guard let t = try? await token() else { return [] }
        return (try? await Supabase.deljeni.rpc("takmicenje_pozivi", [:], token: t)) ?? []
    }

    static func pitanja(_ id: String) async throws -> [Pitanje] { try await Supabase.deljeni.rpc("takmicenje_sadrzaj", ["p_id": id], token: try await token()) }
    static func reci(_ id: String) async throws -> [Rec] { try await Supabase.deljeni.rpc("takmicenje_sadrzaj", ["p_id": id], token: try await token()) }

    /// Domaćinov telefon bira sadržaj istim putem kao igra za jednog (neviđena pitanja, Slikari iz paketa).
    static func izaberi(_ igra: IgraTakmicenja, tezina: String) async throws -> Any {
        switch igra {
        case .pro, .brzi: return json(Array(try await PaketPitanja.deljeni.ucitaj(.opste).prefix(igra.broj)))
        case .book: return json(Array(try await PaketPitanja.deljeni.ucitaj(.book).prefix(igra.broj)))
        case .slikari: return json(try PaketPitanja.slikari(broj: igra.broj, tesko: tezina == "tesko"))
        case .vesanje: return json(Array(try await PaketPitanja.deljeni.reci().prefix(igra.broj)))
        }
    }

    /// Serverske poruke na srpskom za ekran sobe.
    static func poruka(_ g: Error) -> String {
        let p = (g as? Supabase.Greska)?.poruka ?? g.localizedDescription
        if p.contains("ne postoji") { return "Soba ne postoji ili je igra završena. Proveri kod." }
        if p.contains("puna") { return "Soba je puna." }
        if p.contains("već počela") { return "Igra je već počela bez tebe." }
        if p.contains("niko nije ušao") { return "Još niko nije ušao. Sačekaj prijatelje ili pozovi računar." }
        return p
    }
}
