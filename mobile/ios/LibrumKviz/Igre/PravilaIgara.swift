import Foundation

// Pravila Brzog kviza i Vešanja, ista kao na vebu (src/app/brzi-kviz/start,
// src/app/vesanje/start), da rezultati iz aplikacije stoje na istoj rang listi.

/// Brzi kviz: 60 sekundi, prikazan odgovor je tačan ili netačan, +10 / −5.
struct BrziKviz: Equatable {
    static let sekundiRunde = 60
    static let sekundiPoIzjavi = 10
    static let poenaTacno = 10
    static let poenaNetacno = 5

    struct Izjava: Equatable {
        let pitanje: String
        let prikazano: String
        let jeTacno: Bool
        let tacanOdgovor: String

        /// Polovina izjava nudi tačan odgovor, ostale nasumičan netačan.
        init(_ p: Pitanje, nasumicno: () -> Double = { Double.random(in: 0..<1) }) {
            let tacan = p.options[p.correct_answer]
            let netacni = p.options.enumerated().filter { $0.offset != p.correct_answer }.map(\.element)
            pitanje = p.question_text
            tacanOdgovor = tacan
            if nasumicno() < 0.5 || netacni.isEmpty {
                prikazano = tacan
            } else {
                prikazano = netacni[min(netacni.count - 1, Int(nasumicno() * Double(netacni.count)))]
            }
            jeTacno = prikazano == tacan
        }
    }

    var poeni = 0
    var tacnih = 0
    var netacnih = 0

    /// `kaze` je igračev odgovor („tačno” = true); vraća da li je pogodio.
    mutating func odgovor(_ izjava: Izjava, kaze: Bool?) -> Bool {
        let pogodio = kaze == izjava.jeTacno
        if pogodio { poeni += Self.poenaTacno; tacnih += 1 } else { poeni = max(0, poeni - Self.poenaNetacno); netacnih += 1 }
        return pogodio
    }

    func red(korisnik: String, sekundi: Int) -> [String: Any] {
        let ukupno = tacnih + netacnih
        return [
            "user_id": korisnik, "score": poeni, "correct_count": tacnih, "wrong_count": netacnih, "total_answered": ukupno,
            "accuracy": ukupno > 0 ? (Double(tacnih) / Double(ukupno) * 10000).rounded() / 100 : 0,
            "duration_seconds": min(Self.sekundiRunde, max(1, sekundi)),
        ]
    }
}

/// Vešanje: 6 života, slovo +5 po pojavljivanju, promašaj −2 i život, cela reč
/// +20 (+30 bez greške, +15 do dve greške), pogrešna cela reč −2 života.
struct Vesanje: Equatable {
    static let azbuka = ["A","B","C","Č","Ć","D","Đ","E","F","G","H","I","J","K","L","M","N","O","P","R","S","Š","T","U","V","Z","Ž"]
    static let pocetniZivoti = 6
    static let poenaSlovo = 5
    static let poenaPromasaj = 2
    static let bonusRec = 20
    static let bonusBezGreske = 30
    static let bonusMaloGresaka = 15

    enum Status: Equatable { case igra, pobeda, poraz }

    let rec: String
    private(set) var pogodjena: Set<String> = []
    private(set) var promasena: Set<String> = []
    private(set) var zivoti = pocetniZivoti
    private(set) var poeni = 0
    private(set) var status: Status = .igra

    init(rec: String) { self.rec = rec }

    private static func norm(_ s: String) -> String { s.lowercased(with: Locale(identifier: "sr_Latn")) }
    private static func jeSlovo(_ c: Character) -> Bool { c.isLetter }

    /// Prikaz reči: otkrivena slova velikim, skrivena kao „_”, razmaci i crtice ostaju.
    var prikaz: [String] {
        rec.map { c in
            guard Self.jeSlovo(c) else { return String(c) }
            return pogodjena.contains(Self.norm(String(c))) ? String(c).uppercased() : "_"
        }
    }

    var sveOtkriveno: Bool { rec.allSatisfy { !Self.jeSlovo($0) || pogodjena.contains(Self.norm(String($0))) } }

    func iskorisceno(_ slovo: String) -> Bool { pogodjena.contains(Self.norm(slovo)) || promasena.contains(Self.norm(slovo)) }

    private var bonusZaGreske: Int { promasena.isEmpty ? Self.bonusBezGreske : promasena.count <= 2 ? Self.bonusMaloGresaka : 0 }

    mutating func pogodi(_ slovo: String) {
        let n = Self.norm(slovo)
        guard status == .igra, !iskorisceno(slovo) else { return }
        let pojavljivanja = rec.filter { Self.norm(String($0)) == n }.count
        if pojavljivanja > 0 {
            pogodjena.insert(n)
            poeni += pojavljivanja * Self.poenaSlovo
            if sveOtkriveno { poeni += bonusZaGreske; status = .pobeda }
        } else {
            promasena.insert(n)
            zivoti -= 1
            poeni = max(0, poeni - Self.poenaPromasaj)
            if zivoti <= 0 { status = .poraz }
        }
    }

    /// Pomoć: otkriva jedno skriveno slovo bez poena i bez trošenja života.
    @discardableResult
    mutating func otkrijSlovo() -> String? {
        guard status == .igra, let c = rec.first(where: { Self.jeSlovo($0) && !pogodjena.contains(Self.norm(String($0))) }) else { return nil }
        pogodjena.insert(Self.norm(String(c)))
        if sveOtkriveno { poeni += bonusZaGreske; status = .pobeda }
        return String(c).uppercased()
    }

    mutating func pogodiRec(_ pokusaj: String) {
        guard status == .igra else { return }
        if Self.norm(pokusaj.trimmingCharacters(in: .whitespaces)) == Self.norm(rec) {
            for c in rec where Self.jeSlovo(c) { pogodjena.insert(Self.norm(String(c))) }
            poeni += Self.bonusRec + bonusZaGreske
            status = .pobeda
        } else {
            zivoti -= 2
            if zivoti <= 0 { zivoti = 0; status = .poraz }
        }
    }

    func red(korisnik: String, recId: String?, hint: String?, kategorija: String?, sekundi: Int) -> [String: Any] {
        var r: [String: Any] = [
            "user_id": korisnik, "word": rec, "word_length": rec.filter(\.isLetter).count, "won": status == .pobeda,
            "wrong_guesses": promasena.count, "letters_used": pogodjena.count + promasena.count, "time_seconds": sekundi, "score": poeni,
        ]
        if let recId, !recId.hasPrefix("r") { r["word_id"] = recId }
        if let hint { r["hint"] = hint }
        if let kategorija { r["category"] = kategorija }
        return r
    }
}
