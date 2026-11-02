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
        let poruka: String
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

    func zahtev(_ putanja: String, metod: String = "GET", telo: Any? = nil, token: String? = nil, upit: [URLQueryItem] = [], vratiRed: Bool = false) async throws -> Data {
        var komponente = URLComponents(url: osnova.appendingPathComponent(putanja), resolvingAgainstBaseURL: false)!
        if !upit.isEmpty { komponente.queryItems = upit }
        var r = URLRequest(url: komponente.url!, timeoutInterval: 15)
        r.httpMethod = metod
        r.setValue(kljuc, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(token ?? kljuc)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if vratiRed { r.setValue("return=representation", forHTTPHeaderField: "Prefer") }
        if let telo { r.httpBody = try JSONSerialization.data(withJSONObject: telo) }
        let data: Data, odgovor: URLResponse
        do {
            (data, odgovor) = try await URLSession.shared.data(for: r)
        } catch is URLError {
            throw Greska(poruka: "Nema veze sa serverom. Proveri internet i pokušaj ponovo.")
        }
        let kod = (odgovor as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(kod) else { throw Greska(poruka: Self.prevedi(data, kod: kod)) }
        return data
    }

    /// Poruke GoTrue/PostgREST na srpskom; nepoznate se prikazuju kako stignu.
    static func prevedi(_ data: Data, kod: Int) -> String {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let poruka = (json?["error_description"] ?? json?["msg"] ?? json?["message"]) as? String ?? ""
        switch poruka {
        case "Invalid login credentials": return "Pogrešan email ili lozinka."
        case "User already registered": return "Ovaj email je već registrovan."
        case "Email not confirmed": return "Potvrdi email preko linka koji smo ti poslali."
        default:
            if kod == 402 { return "Baza je trenutno nedostupna. Pokušaj kasnije." }
            return poruka.isEmpty ? "Greška \(kod). Pokušaj ponovo." : poruka
        }
    }

    // MARK: Prijava

    func prijava(email: String, lozinka: String) async throws -> Token {
        let d = try await zahtev("auth/v1/token", metod: "POST", telo: ["email": email, "password": lozinka],
                                 upit: [URLQueryItem(name: "grant_type", value: "password")])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    func osvezi(_ refresh: String) async throws -> Token {
        let d = try await zahtev("auth/v1/token", metod: "POST", telo: ["refresh_token": refresh],
                                 upit: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        return try JSONDecoder().decode(Token.self, from: d)
    }

    func registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) async throws {
        _ = try await zahtev("auth/v1/signup", metod: "POST", telo: [
            "email": email, "password": lozinka,
            "data": ["first_name": ime, "last_name": prezime, "nickname": nadimak],
        ])
    }

    func odjava(token: String) async {
        _ = try? await zahtev("auth/v1/logout", metod: "POST", token: token)
    }

    // MARK: Podaci

    func rpc<T: Decodable>(_ ime: String, _ parametri: [String: Any], token: String? = nil) async throws -> T {
        let d = try await zahtev("rest/v1/rpc/\(ime)", metod: "POST", telo: parametri, token: token)
        return try JSONDecoder().decode(T.self, from: d)
    }

    func citaj<T: Decodable>(_ tabela: String, upit: [URLQueryItem], token: String? = nil) async throws -> T {
        let d = try await zahtev("rest/v1/\(tabela)", token: token, upit: upit)
        return try JSONDecoder().decode(T.self, from: d)
    }

    /// PATCH sa filterom (npr. room_code=eq.ABC); vraća izmenjene redove.
    func azuriraj<T: Decodable>(_ tabela: String, filter: [URLQueryItem], polja: [String: Any], token: String) async throws -> [T] {
        let d = try await zahtev("rest/v1/\(tabela)", metod: "PATCH", telo: polja, token: token, upit: filter, vratiRed: true)
        return try JSONDecoder().decode([T].self, from: d)
    }

    func upisiVrati<T: Decodable>(_ tabela: String, _ red: [String: Any], token: String) async throws -> [T] {
        let d = try await zahtev("rest/v1/\(tabela)", metod: "POST", telo: red, token: token, vratiRed: true)
        return try JSONDecoder().decode([T].self, from: d)
    }

    func upisi(_ tabela: String, _ red: [String: Any], token: String) async throws {
        _ = try await zahtev("rest/v1/\(tabela)", metod: "POST", telo: red, token: token)
    }
}
