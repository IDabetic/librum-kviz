import Foundation

/// Poslednji odgovor servera po ključu (memorija + disk). Vlasnik 04.11: ekrani su na sekund imali drugačiji izgled
/// (skelet ili stari raspored) pre nego što stignu podaci; sada se crtaju odmah iz keša, a sveže stiže tiho.
/// Brisanje na odjavi (`Sesija.odjava`), da drugi nalog ne vidi tuđe podatke.
///
/// Primer: `@State private var stanje: Ucitano<[Red]> = Kes.ucitano("rang-osvajanje")`, posle učitavanja `Kes.sacuvaj(redovi, "rang-osvajanje")`.
enum Kes {
    private static let brava = NSLock()
    nonisolated(unsafe) private static var memorija: [String: Data] = [:]
    private static let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("kes", isDirectory: true)

    private static func putanja(_ kljuc: String) -> URL {
        folder.appendingPathComponent(kljuc.replacingOccurrences(of: "/", with: "_") + ".json")
    }

    static func ucitaj<T: Decodable>(_ kljuc: String, kao: T.Type = T.self) -> T? {
        brava.lock()
        let uMemoriji = memorija[kljuc]
        brava.unlock()
        guard let d = uMemoriji ?? (try? Data(contentsOf: putanja(kljuc))) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    /// Stanje ekrana pre mreže: sačuvani podaci ako postoje, inače skelet.
    static func ucitano<T: Decodable>(_ kljuc: String) -> Ucitano<T> {
        ucitaj(kljuc).map { .gotovo($0) } ?? .ucitava
    }

    static func sacuvaj<T: Encodable>(_ vrednost: T, _ kljuc: String) {
        guard let d = try? JSONEncoder().encode(vrednost) else { return }
        brava.lock()
        memorija[kljuc] = d
        brava.unlock()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? d.write(to: putanja(kljuc), options: .atomic)
    }

    static func obrisiSve() {
        brava.lock()
        memorija = [:]
        brava.unlock()
        try? FileManager.default.removeItem(at: folder)
    }
}
