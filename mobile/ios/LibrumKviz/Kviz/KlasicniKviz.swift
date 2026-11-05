import Foundation

/// Pravila kviza po temi (tok iz kita): 10 pitanja, 15 s, 100 za tačan + brzina + niz.
struct KlasicniKviz {
    static let osnovno = 100
    static let brzinaPoSekundi = 2
    static let nizOd = 3
    static let bonusNiza = 20

    struct Zapis: Identifiable {
        let id = UUID()
        let prikaz: Prikaz
        let izabran: Int?
        let preskoceno: Bool
        let ms: Int
        let poeni: Int
        var tacno: Bool { izabran == prikaz.tacan }
    }

    private(set) var zapisi: [Zapis] = []
    private(set) var niz = 0
    private(set) var najduziNiz = 0

    var poeni: Int { zapisi.reduce(0) { $0 + $1.poeni } }
    var tacnih: Int { zapisi.filter(\.tacno).count }
    var netacnih: Int { zapisi.filter { !$0.tacno && !$0.preskoceno }.count }
    var brzih: Int { zapisi.filter { $0.tacno && $0.ms < 2000 }.count }

    /// Upisuje odgovor; vraća (poeni, brzinski bonus, bonus niza) za list posle odgovora.
    @discardableResult
    mutating func odgovor(_ prikaz: Prikaz, izabran: Int?, ostaloSekundi: Double, ms: Int) -> (ukupno: Int, brzina: Int, niz: Int) {
        guard izabran == prikaz.tacan else {
            niz = 0
            zapisi.append(Zapis(prikaz: prikaz, izabran: izabran, preskoceno: false, ms: ms, poeni: 0))
            return (0, 0, 0)
        }
        niz += 1
        najduziNiz = max(najduziNiz, niz)
        let brzina = Int(max(0, ostaloSekundi)) * Self.brzinaPoSekundi
        let bonusNiza = niz >= Self.nizOd ? Self.bonusNiza : 0
        let ukupno = Self.osnovno + brzina + bonusNiza
        zapisi.append(Zapis(prikaz: prikaz, izabran: izabran, preskoceno: false, ms: ms, poeni: ukupno))
        return (ukupno, brzina, bonusNiza)
    }

    /// Preskok ne kvari niz i ne donosi poene.
    mutating func preskok(_ prikaz: Prikaz) {
        zapisi.append(Zapis(prikaz: prikaz, izabran: nil, preskoceno: true, ms: 0, poeni: 0))
    }

    /// Zvezdice na rezultatu: 1 za bar 4, 2 za bar 7, 3 za 10 tačnih.
    static func zvezdice(tacnih: Int, od ukupno: Int) -> Int {
        guard ukupno > 0 else { return 0 }
        let deo = Double(tacnih) / Double(ukupno)
        return deo >= 1 ? 3 : deo >= 0.7 ? 2 : deo >= 0.4 ? 1 : 0
    }
}
