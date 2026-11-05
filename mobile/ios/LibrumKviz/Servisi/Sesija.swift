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
    /// Avatar sa veba (`animal_07.png` u profiles.avatar), isti na sajtu i u aplikaciji.
    private(set) var avatar: String?
    /// Prijavljen bez nadimka (prvi ulaz preko Apple ili Google naloga): app traži profil pre igre.
    private(set) var trebaDopuna = false
    private var token: Supabase.Token?

    private let api = Supabase.deljeni
    private static let kljucKeychain = "club.librum.kviz.sesija"

    var prijavljen: Bool { korisnikId != nil }

    /// Poslednja napravljena sesija (aplikacija ima jednu), za servise van prikaza.
    static weak var trenutna: Sesija?

    init() {
        defer { Sesija.trenutna = self }
        if let podaci = Self.citajKeychain(), let t = try? JSONDecoder().decode(Supabase.Token.self, from: podaci) {
            primeni(t)
            // Nadimak i avatar od prvog kadra (pozdrav na početnoj, profil), sveži stižu iz ucitajNadimak.
            if let k: Licno = Kes.ucitaj("moj-nalog"), k.id == t.user.id {
                nadimak = k.nadimak; avatar = k.avatar; trebaDopuna = k.trebaDopuna
            }
        }
    }

    private struct Licno: Codable { let id: String; let nadimak: String?; let avatar: String?; let trebaDopuna: Bool }

    func prijava(email: String, lozinka: String) async throws {
        let t = try await api.prijava(email: email.trimmingCharacters(in: .whitespaces).lowercased(), lozinka: lozinka)
        primeni(t)
        sacuvaj(t)
        await ucitajNadimak()
    }

    /// Apple šalje ime i prezime samo pri prvoj prijavi; upisuju se u profil ako su tamo prazni.
    func prijavaTokenom(provajder: String, idToken: String, nonce: String?, ime: String? = nil, prezime: String? = nil) async throws {
        let t = try await api.prijavaTokenom(provajder: provajder, idToken: idToken, nonce: nonce)
        primeni(t)
        sacuvaj(t)
        await upisiImeAkoNema(ime, prezime)
        await ucitajNadimak()
    }

    private func upisiImeAkoNema(_ ime: String?, _ prezime: String?) async {
        guard ime?.isEmpty == false || prezime?.isEmpty == false, let staro = try? await licniPodaci() else { return }
        var novo = staro
        if (novo.first_name ?? "").isEmpty, let ime, !ime.isEmpty { novo.first_name = ime }
        if (novo.last_name ?? "").isEmpty, let prezime, !prezime.isEmpty { novo.last_name = prezime }
        if novo != staro { try? await sacuvajLicnePodatke(novo) }
    }

    /// Nalog bez nadimka (prvi ulaz preko Apple/Google) dobija nadimak sam: Apple (smernica 4, Sign in with Apple)
    /// zabranjuje da se posle te prijave traže ime ili mejl. Igrač ga menja u Podešavanjima.
    private func dodeliNadimak(osnova: String?) async {
        let koren = Self.nadimakOd(osnova)
        for pokusaj in 0..<5 {
            let predlog = pokusaj == 0 && koren.count >= 3 ? koren : "\(koren.isEmpty ? "igrac" : koren)\(Int.random(in: 1000...9999))"
            if (try? await sacuvajNadimak(predlog)) != nil { return }
        }
    }

    /// Latinična mala slova i cifre, do 14 znakova (ostaje mesta za 4 cifre do granice od 20).
    /// Primer: nadimakOd("Đorđe") == "djordje"
    static func nadimakOd(_ s: String?) -> String {
        let bez = (s ?? "").lowercased().replacingOccurrences(of: "đ", with: "dj")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "sr_Latn"))
        return String(bez.unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(Character.init).prefix(14))
    }

    func registracija(email: String, lozinka: String, ime: String, prezime: String, nadimak: String) async throws {
        try await api.registracija(email: email.trimmingCharacters(in: .whitespaces).lowercased(), lozinka: lozinka,
                                   ime: ime, prezime: prezime, nadimak: nadimak)
    }

    /// Kod iz mejla posle registracije ili za novu lozinku; posle uspeha korisnik je prijavljen.
    func potvrdiKod(email: String, kod: String, oporavak: Bool = false) async throws {
        let t = try await api.potvrdiKod(email: email.trimmingCharacters(in: .whitespaces).lowercased(), kod: kod, vrsta: oporavak ? "recovery" : "signup")
        primeni(t)
        sacuvaj(t)
        await ucitajNadimak()
    }

    func posaljiKodPonovo(email: String) async throws { try await api.posaljiKodPonovo(email: email.lowercased()) }
    func zaboravljenaLozinka(email: String) async throws { try await api.zaboravljenaLozinka(email: email.trimmingCharacters(in: .whitespaces).lowercased()) }

    func postaviLozinku(_ lozinka: String) async throws {
        guard let t = try await vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se ponovo.") }
        try await api.novaLozinka(lozinka, token: t)
    }

    /// Nadimak je jedinstven: provera u javnim profilima pre upisa.
    func sacuvajNadimak(_ novi: String) async throws {
        guard let id = korisnikId, let t = try await vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se ponovo.") }
        struct Red: Decodable { let id: String }
        let zauzet: [Red] = try await api.citaj("public_profiles", upit: [
            URLQueryItem(name: "select", value: "id"), URLQueryItem(name: "nickname", value: "ilike.\(novi)"), URLQueryItem(name: "id", value: "neq.\(id)"),
        ])
        guard zauzet.isEmpty else { throw Supabase.Greska(poruka: "Nadimak „\(novi)” je zauzet.", vrsta: .postoji) }
        let _: [Red] = try await api.azuriraj("profiles", filter: [URLQueryItem(name: "id", value: "eq.\(id)")], polja: ["nickname": novi], token: t)
        nadimak = novi
        trebaDopuna = false
        sacuvajLicno()
    }

    /// Lični podaci profila koje vide i drugi (ime, prezime, grad, „o meni”).
    struct LicniPodaci: Codable, Equatable { var first_name: String?; var last_name: String?; var city: String?; var bio: String? }

    func licniPodaci() async throws -> LicniPodaci {
        guard let id = korisnikId, let t = try await vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se ponovo.") }
        let r: [LicniPodaci] = try await api.citaj("profiles", upit: [URLQueryItem(name: "select", value: "first_name,last_name,city,bio"),
                                                                       URLQueryItem(name: "id", value: "eq.\(id)")], token: t)
        return r.first ?? LicniPodaci()
    }

    func sacuvajLicnePodatke(_ p: LicniPodaci) async throws {
        guard let id = korisnikId, let t = try await vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se ponovo.") }
        struct Red: Decodable { let id: String }
        // Prazno polje se čuva kao null, da profil ne prikazuje prazan red.
        func ili(_ s: String?) -> Any { s.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0.trimmingCharacters(in: .whitespaces) } ?? NSNull() }
        let _: [Red] = try await api.azuriraj("profiles", filter: [URLQueryItem(name: "id", value: "eq.\(id)")],
                                             polja: ["first_name": ili(p.first_name), "last_name": ili(p.last_name), "city": ili(p.city), "bio": ili(p.bio)], token: t)
    }

    func sacuvajAvatar(_ novi: String) async throws {
        guard let id = korisnikId, let t = try await vazeciToken() else { throw Supabase.Greska(poruka: "Prijavi se ponovo.") }
        struct Red: Decodable { let id: String }
        let _: [Red] = try await api.azuriraj("profiles", filter: [URLQueryItem(name: "id", value: "eq.\(id)")], polja: ["avatar": novi], token: t)
        avatar = novi; sacuvajLicno()
    }

    /// Rezultat partije za rang liste po igri (tabela rezultati_igara). Bez naloga se ništa ne šalje.
    func upisiRezultat(igra: String, poeni: Int, tacnih: Int, netacnih: Int, prosekMs: Int?, pomoc: String? = nil, nacin: String? = nil, izdaja: Int? = nil) async {
        guard let id = korisnikId, let t = try? await vazeciToken() else { return }
        var red: [String: Any] = ["user_id": id, "igra": igra, "poeni": max(0, poeni), "tacnih": tacnih, "netacnih": netacnih]
        if let prosekMs { red["prosek_ms"] = min(120_000, max(0, prosekMs)) }
        if let pomoc { red["pomoc"] = pomoc }
        // Osvajanje: sam, savez ili zajedno (profil igrača pokazuje kako najčešće igra).
        if let nacin { red["nacin"] = nacin }
        if let izdaja { red["izdaja"] = izdaja }
        try? await api.upisi("rezultati_igara", red, token: t)
    }

    func odjava() async {
        if let t = token { await api.odjava(token: t.access_token) }
        ocisti()
        Kes.obrisiSve()
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
        struct Profil: Decodable { let nickname: String?; let first_name: String?; let avatar: String? }
        let redovi: [Profil]? = try? await api.citaj("public_profiles", upit: [
            URLQueryItem(name: "select", value: "nickname,first_name,avatar"), URLQueryItem(name: "id", value: "eq.\(id)"),
        ])
        guard let profil = redovi?.first else { return }
        let nick = profil.nickname.flatMap { $0.isEmpty ? nil : $0 }
        nadimak = nick ?? profil.first_name.flatMap { $0.isEmpty ? nil : $0 }
        avatar = profil.avatar
        trebaDopuna = false
        sacuvajLicno()
        if nick == nil { await dodeliNadimak(osnova: profil.first_name) }
    }

    private func sacuvajLicno() {
        guard let id = korisnikId else { return }
        Kes.sacuvaj(Licno(id: id, nadimak: nadimak, avatar: avatar, trebaDopuna: trebaDopuna), "moj-nalog")
    }

    private func primeni(_ t: Supabase.Token) {
        token = t
        korisnikId = t.user.id
        email = t.user.email
    }

    private func ocisti() {
        token = nil; korisnikId = nil; email = nil; nadimak = nil; avatar = nil; trebaDopuna = false
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
