import Foundation

struct Pitanje: Codable, Identifiable, Equatable {
    let id: String
    let question_text: String
    let options: [String]
    let correct_answer: Int
}

/// Pitanje spremno za prikaz: ponude promešane, zna se koja je tačna.
struct Prikaz: Equatable {
    let tekst: String
    let opcije: [String]
    let tacan: Int

    init(_ p: Pitanje) {
        let red = [0, 1, 2, 3].shuffled()
        tekst = p.question_text
        opcije = red.map { p.options[$0] }
        tacan = red.firstIndex(of: p.correct_answer) ?? 0
    }
}

/// Paket pitanja iz RPC `osvajanje_pitanja`, keširan na disku. Bez mreže igra
/// ide iz poslednjeg paketa; tako jedna partija troši jedan mali zahtev.
actor PaketPitanja {
    static let deljeni = PaketPitanja()
    private let velicina = 60

    private var fajl: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("paket-pitanja.json")
    }

    /// Svež paket ako mreža radi, inače keš. Baca grešku samo kad nema ni jednog.
    func ucitaj() async throws -> [Pitanje] {
        do {
            let svez: [Pitanje] = try await Supabase.deljeni.rpc("osvajanje_pitanja", ["p_broj": velicina])
            let ispravna = svez.filter { $0.options.count == 4 && (0..<4).contains($0.correct_answer) }
            if !ispravna.isEmpty {
                try? JSONEncoder().encode(ispravna).write(to: fajl, options: .atomic)
                return ispravna.shuffled()
            }
        } catch {
            // Pada na keš ispod; greška se prijavljuje samo ako ni njega nema.
        }
        if let d = try? Data(contentsOf: fajl), let kes = try? JSONDecoder().decode([Pitanje].self, from: d), !kes.isEmpty {
            return kes.shuffled()
        }
        // Prvo pokretanje bez mreže ili baza ne odgovara: rezervni paket ugrađen u aplikaciju (isti kao veb).
        if let url = Bundle.main.url(forResource: "rezervna-pitanja", withExtension: "json"),
           let d = try? Data(contentsOf: url),
           let redovi = try? JSONSerialization.jsonObject(with: d) as? [[Any]] {
            let rezerva = redovi.enumerated().compactMap { i, r -> Pitanje? in
                guard r.count == 3, let t = r[0] as? String, let o = r[1] as? [String], let c = r[2] as? Int else { return nil }
                return Pitanje(id: "r\(i)", question_text: t, options: o, correct_answer: c)
            }
            if !rezerva.isEmpty { return rezerva.shuffled() }
        }
        throw Supabase.Greska(poruka: "Pitanja nisu stigla. Proveri internet i pokušaj ponovo.")
    }
}

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
