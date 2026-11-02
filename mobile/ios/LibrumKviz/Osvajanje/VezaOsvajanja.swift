import Foundation

/// Partija Osvajanja preko servera (scripts/2026-11-03_osvajanje-potezi.sql): dnevnik poteza po sobi.
/// Domaćin (mesto 0) šalje početno stanje i vodi botove; igrač na potezu šalje stanje posle bitaka i na kraju poteza;
/// bitka protiv pravog igrača je par „bitka” (napadač i njegov skor) → „odbrana” (skor branioca).
@MainActor
final class VezaOsvajanja {
    struct Akcija: Codable {
        var v: String
        var stanje: Stanje?
        var odakle: String?
        var kuda: String?
        var skor: Skor?
        /// Redni broj „bitke” na koju se „odbrana” odnosi.
        var bitka: Int?
    }
    struct Red: Decodable { let rb: Int; let ko: String; let akcija: Akcija }

    let soba: String
    let ja: String
    let domacin: Bool
    private(set) var poslednji = 0

    /// Id igrača u stanju: „u:” + id naloga, isti na svakom telefonu.
    static func idIgraca(_ korisnik: String) -> String { "u:" + korisnik }
    var mojId: String { Self.idIgraca(ja) }

    init(soba: String, ja: String, domacin: Bool) {
        self.soba = soba; self.ja = ja; self.domacin = domacin
    }

    private func token() async -> String? { try? await Sesija.trenutna?.vazeciToken() }

    @discardableResult
    func posalji(_ a: Akcija) async -> Int? {
        guard let t = await token(), let d = try? JSONEncoder().encode(a), let obj = try? JSONSerialization.jsonObject(with: d) else { return nil }
        return try? await Supabase.deljeni.rpc("osvajanje_upisi", ["p_soba": soba, "p_akcija": obj], token: t)
    }

    /// Novi potezi drugih igrača (svoje već znam).
    func novi() async -> [Red] {
        guard let t = await token(), let redovi: [Red] = try? await Supabase.deljeni.rpc("osvajanje_potezi_od", ["p_soba": soba, "p_od": poslednji], token: t)
        else { return [] }
        if let m = redovi.map(\.rb).max() { poslednji = m }
        return redovi.filter { $0.ko != ja }
    }
}
