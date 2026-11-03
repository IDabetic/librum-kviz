import Foundation

/// Kraj svake partije na jednom mestu: lokalni napredak (XP, bedževi, niz) i rezultat
/// za rang listu po igri na serveru (samo za prijavljene).
@MainActor
@discardableResult
func zavrsiPartiju(_ napredak: Napredak, _ sesija: Sesija, igra: String, kviz: String? = nil, poeni: Int, tacnih: Int, netacnih: Int,
                   kategorija: String? = nil, brzih: Int = 0, pobeda: Bool = false, prosekMs: Int? = nil,
                   odgovori: [(id: String?, tacno: Bool)] = []) -> Napredak.Ishod {
    let pomoc = napredak.pomocUPartiji
    let ishod = napredak.zabeleziIgru(kviz: kviz ?? igra, tacnih: tacnih, netacnih: netacnih, kategorija: kategorija,
                                      brzih: brzih, pobeda: pobeda, prosekMs: prosekMs)
    napredak.pomocUPartiji = nil
    Task { await sesija.upisiRezultat(igra: igra, poeni: poeni, tacnih: tacnih, netacnih: netacnih, prosekMs: prosekMs, pomoc: pomoc) }
    // Ishodi pitanja određuju težinu (scripts/2026-11-03_tezina-iz-statistike.sql); Slikari i rezerva nemaju id u bazi.
    let zapis = odgovori.compactMap { o in o.id.map { ["id": $0, "tacno": o.tacno] as [String: Any] } }.prefix(100)
    if !zapis.isEmpty { Task { let _: String? = try? await Supabase.deljeni.rpc("zabelezi_odgovore", ["p_odgovori": Array(zapis)]) } }
    return ishod
}

/// Prosek u milisekundama ili nil kad nema merenja.
func prosek(_ zbir: Int, _ broj: Int) -> Int? { broj > 0 ? zbir / broj : nil }
