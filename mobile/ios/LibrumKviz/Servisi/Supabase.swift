import Foundation

/// Tanak klijent za Supabase REST (GoTrue + PostgREST), bez spoljnih paketa.
/// Isti javni ključ kao veb (NEXT_PUBLIC_*); bazu štiti RLS.
struct Supabase {
    static let deljeni = Supabase()

    let osnova: URL
    let kljuc: String

    init(bundle: Bundle = .main) {
        let host = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        osnova = URL(string: "https://\(host)")!
        kljuc = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    struct Greska: LocalizedError {
        enum Vrsta { case mreza, zakljucano, pogresno, istekao, postoji, nepotvrdjen, ostalo }
        let poruka: String
        var vrsta: Vrsta = .ostalo
        var errorDescription: String? { poruka }
    }

    struct Token: Codable {
        let access_token: String
        let refresh_token: String
        let expires_at: Double?
        let user: Korisnik
    }

    struct Korisnik: Codable {
        let id: String
        let email: String?
    }

    func zahtev(_ putanja: String, metod: String = "GET", telo: Any? = nil, token: String? = nil, upit: [URLQueryItem] = [], vratiRed: Bool = false, dodatnaZaglavlja: [String: String] = [:]) async throws -> Data {
        var komponente = URLComponents(url: osnova.appendingPathComponent(putanja), resolvingAgainstBaseURL: false)!
        if !upit.isEmpty { komponente.queryItems = upit }
        var r = URLRequest(url: komponente.url!, timeoutInterval: 15)
        r.httpMethod = metod
        r.setValue(kljuc, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(token ?? kljuc)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if vratiRed { r.setValue("return=representation", forHTTPHeaderField: "Prefer") }
        for (k, v) in dodatnaZaglavlja { r.setValue(v, forHTTPHeaderField: k) }
        if let telo { r.httpBody = try JSONSerialization.data(withJSONObject: telo) }
        let data: Data, odgovor: URLResponse
        do {
            (data, odgovor) = try await URLSession.shared.data(for: r)
        } catch is URLError {
            throw Greska(poruka: "Nema veze sa serverom. Proveri internet i pokušaj ponovo.", vrsta: .mreza)
        }
        let kod = (odgovor as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(kod) else { throw Self.greska(data, kod: kod) }
        return data
    }

    /// Poruke GoTrue/PostgREST na srpskom, sa vrstom za stanja ekrana iz kita.
    static func greska(_ data: Data, kod: Int) -> Greska {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let poruka = (json?["error_description"] ?? json?["msg"] ?? json?["message"]) as? String ?? ""
        let k = (json?["error_code"] ?? json?["code"]) as? String ?? ""
        if kod == 429 || k.contains("rate_limit") || poruka.contains("only request this after") {
            return Greska(poruka: "Previše pokušaja. Sačekaj malo pa probaj ponovo.", vrsta: .zakljucano)
        }
        if k == "otp_expired" || poruka.contains("expired") {
            return Greska(poruka: "Kod je istekao ili nije tačan. Zatraži novi.", vrsta: .istekao)
        }
        switch poruka {
        case "Invalid login credentials": return Greska(poruka: "Pogrešan email ili lozinka.", vrsta: .pogresno)
        case "User already registered": return Greska(poruka: "Ovaj email je već registrovan.", vrsta: .postoji)
        case "Email not confirmed": return Greska(poruka: "Potvrdi email kodom koji smo ti poslali.", vrsta: .nepotvrdjen)
        default:
            if kod == 402 { return Greska(poruka: "Baza je trenutno nedostupna. Pokušaj kasnije.") }
            // Greške baze (SQLSTATE od 5 znakova) igrač ne treba da čita; prikazujemo samo naše poruke iz funkcija
            // (22023 pogrešan unos, P0001/P0002 pravila igre, 42501 prijava). Primer sakrivenog: 42702 „column reference is ambiguous”.
            let nasa: Set<String> = ["22023", "P0001", "P0002", "42501"]
            if k.count == 5, k.allSatisfy({ $0.isNumber || $0.isUppercase }), !nasa.contains(k) {
                #if DEBUG
                print("Greška servera \(k): \(poruka)")
                #endif
                return Greska(poruka: "Nešto nije u redu na serveru. Pokušaj ponovo za koji trenutak.")
            }
            return Greska(poruka: poruka.isEmpty ? "Nešto nije u redu (greška \(kod)). Pokušaj ponovo." : poruka)
        }
    }

    // MARK: Prijava

    func prijava(email: String, lozinka: String) async throws -> Token {
        let d = try await zahtev("auth/v1/token", metod: "POST", telo: ["email": email, "password": lozinka],
                                 upit: [URLQueryItem(name: "grant_type", value: "password")])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    /// Prijava tokenom sa telefona (Sign in with Apple, Google): Supabase proverava potpis i nonce.
    func prijavaTokenom(provajder: String, idToken: String, nonce: String?) async throws -> Token {
        var telo: [String: Any] = ["provider": provajder, "id_token": idToken]
        if let nonce { telo["nonce"] = nonce }
        let d = try await zahtev("auth/v1/token", metod: "POST", telo: telo, upit: [URLQueryItem(name: "grant_type", value: "id_token")])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    /// Koji spoljni provajderi su uključeni u Supabase (Authentication → Providers); dugmad se prikazuju samo za njih.
    func ukljuceniProvajderi() async -> Set<String> {
        struct P: Decodable { let external: [String: Bool] }
        guard let d = try? await zahtev("auth/v1/settings"), let p = try? JSONDecoder().decode(P.self, from: d) else { return [] }
        return Set(p.external.filter(\.value).map(\.key))
    }

    func osvezi(_ refresh: String) async throws -> Token {
        let d = try await zahtev("auth/v1/token", metod: "POST", telo: ["refresh_token": refresh],
                                 upit: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    func registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) async throws {
        let d = try await zahtev("auth/v1/signup", metod: "POST", telo: [
            "email": email, "password": lozinka,
            "data": ["first_name": ime, "last_name": prezime, "nickname": nadimak],
        ])
        // GoTrue za već potvrđen email vraća 200 bez mejla i sa praznim `identities` (ne otkriva nalog), pa to prevodimo u „postoji”.
        if let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let identiteti = (o["identities"] ?? (o["user"] as? [String: Any])?["identities"]) as? [Any], identiteti.isEmpty {
            throw Greska(poruka: "Ovaj email već ima nalog.", vrsta: .postoji)
        }
    }

    /// Potvrda koda iz mejla (registracija ili zaboravljena lozinka); vraća sesiju.
    func potvrdiKod(email: String, kod: String, vrsta: String) async throws -> Token {
        let d = try await zahtev("auth/v1/verify", metod: "POST", telo: ["type": vrsta, "email": email, "token": kod])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    func posaljiKodPonovo(email: String) async throws {
        _ = try await zahtev("auth/v1/resend", metod: "POST", telo: ["type": "signup", "email": email])
    }

    func zaboravljenaLozinka(email: String) async throws {
        _ = try await zahtev("auth/v1/recover", metod: "POST", telo: ["email": email])
    }

    func novaLozinka(_ lozinka: String, token: String) async throws {
        _ = try await zahtev("auth/v1/user", metod: "PUT", telo: ["password": lozinka], token: token)
    }

    func odjava(token: String) async {
        _ = try? await zahtev("auth/v1/logout", metod: "POST", token: token)
    }

    // MARK: Podaci

    func rpc<T: Decodable>(_ ime: String, _ parametri: [String: Any], token: String? = nil) async throws -> T {
        let d = try await zahtev("rest/v1/rpc/\(ime)", metod: "POST", telo: parametri, token: token)
        return try Self.dekodiraj(T.self, d)
    }

    func citaj<T: Decodable>(_ tabela: String, upit: [URLQueryItem], token: String? = nil) async throws -> T {
        let d = try await zahtev("rest/v1/\(tabela)", token: token, upit: upit)
        return try Self.dekodiraj(T.self, d)
    }

    /// PATCH sa filterom (npr. room_code=eq.ABC); vraća izmenjene redove.
    func azuriraj<T: Decodable>(_ tabela: String, filter: [URLQueryItem], polja: [String: Any], token: String) async throws -> [T] {
        let d = try await zahtev("rest/v1/\(tabela)", metod: "PATCH", telo: polja, token: token, upit: filter, vratiRed: true)
        return try Self.dekodiraj([T].self, d)
    }

    func upisiVrati<T: Decodable>(_ tabela: String, _ red: [String: Any], token: String) async throws -> [T] {
        let d = try await zahtev("rest/v1/\(tabela)", metod: "POST", telo: red, token: token, vratiRed: true)
        return try Self.dekodiraj([T].self, d)
    }

    /// Neočekivan oblik odgovora ne sme da pokaže sistemsku englesku poruku („The data couldn’t be read…”).
    private static func dekodiraj<T: Decodable>(_ tip: T.Type, _ d: Data) throws -> T {
        do { return try JSONDecoder().decode(tip, from: d) }
        catch is DecodingError { throw Greska(poruka: "Podaci nisu stigli u ispravnom obliku. Pokušaj ponovo za koji trenutak.") }
    }

    func upisi(_ tabela: String, _ red: [String: Any], token: String) async throws {
        _ = try await zahtev("rest/v1/\(tabela)", metod: "POST", telo: red, token: token)
    }
}
