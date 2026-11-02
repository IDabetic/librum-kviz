import Foundation
import Security
import Observation

/// Prijavljen korisnik: tokeni u Keychainu, osvežavanje pred istek.
@Observable
@MainActor
final class Sesija {
    private(set) var korisnikId: String?
    private(set) var email: String?
    private(set) var nadimak: String?
    private var token: Supabase.Token?

    private let api = Supabase.deljeni
    private static let kljucKeychain = "club.librum.kviz.sesija"

    var prijavljen: Bool { korisnikId != nil }

    init() {
        if let podaci = Self.citajKeychain(), let t = try? JSONDecoder().decode(Supabase.Token.self, from: podaci) {
            primeni(t)
        }
    }

    func prijava(email: String, lozinka: String) async throws {
        let t = try await api.prijava(email: email.trimmingCharacters(in: .whitespaces).lowercased(), lozinka: lozinka)
        primeni(t)
        sacuvaj(t)
        await ucitajNadimak()
    }

    func registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) async throws {
        try await api.registracija(email: email.trimmingCharacters(in: .whitespaces).lowercased(), lozinka: lozinka,
                                   ime: ime, prezime: prezime, nadimak: nadimak)
    }

    func odjava() async {
        if let t = token { await api.odjava(token: t.access_token) }
        ocisti()
    }

    /// Trajno briše nalog na serveru (RPC obrisi_moj_nalog), pa odjavljuje.
    func obrisiNalog() async throws {
        guard let pristup = try await vazeciToken() else { return }
        // RPC vraća void, pa se odgovor ne dekodira.
        _ = try await api.zahtev("rest/v1/rpc/obrisi_moj_nalog", metod: "POST", telo: [String: String](), token: pristup)
        ocisti()
    }

    /// Token koji važi bar još minut; osvežava ga po potrebi.
    func vazeciToken() async throws -> String? {
        guard let t = token else { return nil }
        if let istice = t.expires_at, Date(timeIntervalSince1970: istice).timeIntervalSinceNow < 60 {
            do {
                let novi = try await api.osvezi(t.refresh_token)
                primeni(novi)
                sacuvaj(novi)
                return novi.access_token
            } catch {
                ocisti()
                return nil
            }
        }
        return t.access_token
    }

    func ucitajNadimak() async {
        guard let id = korisnikId else { return }
        struct Profil: Decodable { let nickname: String?; let first_name: String? }
        let redovi: [Profil]? = try? await api.citaj("public_profiles", upit: [
            URLQueryItem(name: "select", value: "nickname,first_name"), URLQueryItem(name: "id", value: "eq.\(id)"),
        ])
        nadimak = redovi?.first.flatMap { $0.nickname ?? $0.first_name }
    }

    private func primeni(_ t: Supabase.Token) {
        token = t
        korisnikId = t.user.id
        email = t.user.email
    }

    private func ocisti() {
        token = nil; korisnikId = nil; email = nil; nadimak = nil
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: Self.kljucKeychain] as CFDictionary)
    }

    private func sacuvaj(_ t: Supabase.Token) {
        guard let podaci = try? JSONEncoder().encode(t) else { return }
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: Self.kljucKeychain] as CFDictionary)
        SecItemAdd([
            kSecClass: kSecClassGenericPassword, kSecAttrAccount: Self.kljucKeychain, kSecValueData: podaci,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary, nil)
    }

    private static func citajKeychain() -> Data? {
        var rezultat: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword, kSecAttrAccount: kljucKeychain, kSecReturnData: true,
        ] as CFDictionary, &rezultat)
        return status == errSecSuccess ? rezultat as? Data : nil
    }
}
