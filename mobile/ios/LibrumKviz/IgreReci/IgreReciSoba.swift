import SwiftUI

/// Igre reči u sobi „Igraj sa drugima”: domaćin uzima nasumičnu zagonetku iz baze izazova (igre_reci_izazov, po težini),
/// šalje je u sobu, a svi igraju istu na svom telefonu sa istim rokom (scripts/2026-11-08_igre-reci-takmicenje.sql).
enum ZagonetkaSobe {
    case premetaljka(PremetaljkaZ), petSlova(PetSlovaZ), lanac(LanacZ), sifra(SifraZ), ukrstenica(UkrstenicaZ), zmija(ZmijaZ)

    /// Domaćin: zagonetka za sadržaj sobe (JSON niz sa jednom zagonetkom). Težina sobe „normalno” je srednja.
    static func izaberi(_ igra: IgraReci, tezina: String) async throws -> Any {
        let token = try await Takmicenje.token()
        let p: [String: Any] = ["p_igra": igra.rawValue, "p_tezina": tezina]
        func jedna<T: Codable>(_: T.Type) async throws -> Any {
            let z: T = try await Supabase.deljeni.rpc("igre_reci_izazov", p, token: token)
            return Takmicenje.json([z])
        }
        switch igra {
        case .premetaljka: return try await jedna(PremetaljkaZ.self)
        case .petSlova: return try await jedna(PetSlovaZ.self)
        case .lanac: return try await jedna(LanacZ.self)
        case .sifra: return try await jedna(SifraZ.self)
        case .ukrstenica: return try await jedna(UkrstenicaZ.self)
        case .zmija: return try await jedna(ZmijaZ.self)
        }
    }

    /// Sadržaj sobe (niz sa jednom zagonetkom) u zagonetku igre. Primer: iz(.zmija, podaci) → .zmija(...).
    static func iz(_ igra: IgraReci, _ podaci: Data) throws -> ZagonetkaSobe {
        func prva<T: Decodable>(_: T.Type) throws -> T {
            guard let z = try JSONDecoder().decode([T].self, from: podaci).first else { throw Supabase.Greska(poruka: "Zagonetka nije stigla.") }
            return z
        }
        switch igra {
        case .premetaljka: return .premetaljka(try prva(PremetaljkaZ.self))
        case .petSlova: return .petSlova(try prva(PetSlovaZ.self))
        case .lanac: return .lanac(try prva(LanacZ.self))
        case .sifra: return .sifra(try prva(SifraZ.self))
        case .ukrstenica: return .ukrstenica(try prva(UkrstenicaZ.self))
        case .zmija: return .zmija(try prva(ZmijaZ.self))
        }
    }

    /// Igrač u sobi: sadržaj sa servera (takmicenje_sadrzaj).
    static func ucitaj(_ igra: IgraReci, soba id: String) async throws -> ZagonetkaSobe {
        let sirovo: SirovSadrzaj = try await Supabase.deljeni.rpc("takmicenje_sadrzaj", ["p_id": id], token: try await Takmicenje.token())
        return try iz(igra, sirovo.podaci)
    }
}

/// Bilo koji JSON odgovor sačuvan kao bajtovi, da ga posle dekodira tip igre.
struct SirovSadrzaj: Decodable {
    let podaci: Data
    init(from decoder: Decoder) throws {
        let v = try decoder.singleValueContainer().decode(JSONVrednost.self)
        podaci = try JSONSerialization.data(withJSONObject: v.objekat, options: [.fragmentsAllowed])
    }
}

/// Minimalni JSON za prepakivanje (nizovi, objekti, tekst, brojevi, logičke vrednosti, null).
indirect enum JSONVrednost: Decodable {
    case niz([JSONVrednost]), objekat([String: JSONVrednost]), tekst(String), broj(Double), da(Bool), nista

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .nista }
        else if let b = try? c.decode(Bool.self) { self = .da(b) }
        else if let n = try? c.decode(Double.self) { self = .broj(n) }
        else if let t = try? c.decode(String.self) { self = .tekst(t) }
        else if let a = try? c.decode([JSONVrednost].self) { self = .niz(a) }
        else { self = .objekat(try c.decode([String: JSONVrednost].self)) }
    }

    var objekat: Any {
        switch self {
        case .niz(let a): a.map(\.objekat)
        case .objekat(let o): o.mapValues(\.objekat)
        case .tekst(let t): t
        // celi brojevi ostaju celi (koordinate, brojevi šifre)
        case .broj(let n): n.rounded() == n && abs(n) < 1e15 ? Int(n) as Any : n as Any
        case .da(let b): b
        case .nista: NSNull()
        }
    }
}

/// Ekran igre u sobi: ista igra kao dnevna, sa rokom i javljanjem poena tabeli uživo.
struct IgraReciUSobi: View {
    let zagonetka: ZagonetkaSobe
    let sobaId: String
    let javi: (MojRezultat) -> Void

    var body: some View {
        let datum = "soba-\(sobaId)"
        switch zagonetka {
        case .premetaljka(let z): PremetaljkaView(z: z, datum: datum, soba: soba(.premetaljka))
        case .petSlova(let z): PetSlovaView(z: z, datum: datum, soba: soba(.petSlova))
        case .lanac(let z): LanacView(z: z, datum: datum, soba: soba(.lanac))
        case .sifra(let z): SifraView(z: z, datum: datum, soba: soba(.sifra))
        case .ukrstenica(let z): UkrstenicaView(z: z, datum: datum, soba: soba(.ukrstenica))
        case .zmija(let z): ZmijaView(z: z, datum: datum, soba: soba(.zmija))
        }
    }

    private func soba(_ igra: IgraReci) -> UTakmicenju { UTakmicenju(rok: UTakmicenju.rok(igra), javi: javi) }
}
