import Foundation
import Observation
import UserNotifications

/// Bedž iz kita: uslov se proverava nad stanjem napretka posle svake igre.
struct Bedz: Identifiable, Equatable {
    let id: String
    let naziv: String
    let opis: String
    let ikonica: String
    let boja: UInt32
    let nagrada: Int
}

/// Lokalni napredak igrača: novčići, XP, niz dana, pomoći, bedževi, statistika i sanduče.
/// Čuva se na uređaju (UserDefaults), radi i bez naloga i bez mreže.
/// shortcut: samo na uređaju; kad Supabase proradi, sinhronizacija ide u tabelu po nalogu.
@Observable
@MainActor
final class Napredak {
    static let deljeni = Napredak()

    struct Dan: Codable { var igara = 0; var tacnih = 0; var netacnih = 0 }
    struct Poruka: Codable, Identifiable {
        enum Vrsta: String, Codable { case nagrada, bedz, izazov, rezultat }
        var id = UUID().uuidString
        let vrsta: Vrsta
        let naslov: String
        let tekst: String
        let vreme: Date
        var procitano = false
        var novcici = 0
        var pokupljeno = false
    }
    struct Stanje: Codable {
        var novcici = 100
        var xp = 0
        var nizDana = 0
        var najduziNiz = 0
        var poslednjiDanIgre: String?
        var poslednjaNagrada: String?
        var danaNagrade = 0
        var igara = 0
        var tacnih = 0
        var netacnih = 0
        var savrsenih = 0
        var brzihOdgovora = 0
        var pobedaDuel = 0
        var pomoci: [String: Int] = ["polaPola": 2, "nagovestaj": 2, "vreme": 2, "preskok": 1]
        var bedzevi: [String: Date] = [:]
        var dani: [String: Dan] = [:]
        var kategorije: [String: [Int]] = [:]   // naziv → [tačnih, ukupno]
        var najbolje: [String: Int] = [:]        // kviz → najbolji broj tačnih
        var poruke: [Poruka] = []
        var cilj = 3
        var podsetnik = true
        var maskota = "Mimi"
        var interesovanja: [String] = []
        var uvodZavrsen = false
        var zvuk = true
        var muzika = false
    }

    private(set) var s: Stanje
    private let kljuc = "napredak.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: kljuc), let st = try? JSONDecoder().decode(Stanje.self, from: d) {
            s = st
        } else {
            s = Stanje()
        }
    }

    // MARK: Nivo

    static let xpPoNivou = 250
    /// Nivo n traži 250 × n XP da se pređe u n+1 (1→2 = 250, 12→13 = 3.000).
    var nivo: Int { Self.nivo(xp: s.xp).nivo }
    var xpUNivou: (imam: Int, treba: Int) { let n = Self.nivo(xp: s.xp); return (n.ostatak, n.nivo * Self.xpPoNivou) }

    static func nivo(xp: Int) -> (nivo: Int, ostatak: Int) {
        var n = 1, ostatak = xp
        while ostatak >= n * xpPoNivou { ostatak -= n * xpPoNivou; n += 1 }
        return (n, ostatak)
    }

    // MARK: Igra

    struct Ishod { let xp: Int; let novcici: Int; let noviBedzevi: [Bedz] }

    /// Upisuje odigranu igru; vraća zarađeno i nove bedževe.
    @discardableResult
    func zabeleziIgru(kviz: String, tacnih: Int, netacnih: Int, kategorija: String? = nil, brzih: Int = 0, pobeda: Bool = false, danas: Date = .now) -> Ishod {
        let dan = Self.dan(danas)
        if s.poslednjiDanIgre != dan {
            s.nizDana = s.poslednjiDanIgre == Self.dan(danas.addingTimeInterval(-86_400)) ? s.nizDana + 1 : 1
            s.najduziNiz = max(s.najduziNiz, s.nizDana)
            s.poslednjiDanIgre = dan
        }
        let xp = tacnih + 5
        let novcici = tacnih * 2 + (netacnih == 0 && tacnih >= 10 ? 50 : 0)
        s.xp += xp
        s.novcici += novcici
        s.igara += 1
        s.tacnih += tacnih
        s.netacnih += netacnih
        s.brzihOdgovora += brzih
        if pobeda { s.pobedaDuel += 1 }
        if netacnih == 0 && tacnih >= 10 { s.savrsenih += 1 }
        s.dani[dan, default: Dan()].igara += 1
        s.dani[dan, default: Dan()].tacnih += tacnih
        s.dani[dan, default: Dan()].netacnih += netacnih
        if let kategorija {
            var k = s.kategorije[kategorija] ?? [0, 0]
            k[0] += tacnih; k[1] += tacnih + netacnih
            s.kategorije[kategorija] = k
        }
        s.najbolje[kviz] = max(s.najbolje[kviz] ?? 0, tacnih)
        let novi = proveriBedzeve(danas)
        sacuvaj()
        return Ishod(xp: xp, novcici: novcici, noviBedzevi: novi)
    }

    // MARK: Dnevna nagrada

    static let nagradeNiza = [10, 20, 30, 40, 50, 60, 100]

    var dnevnaNagradaSpremna: Bool { s.poslednjaNagrada != Self.dan(.now) }
    var sledecaNagrada: Int { Self.nagradeNiza[min(s.danaNagrade, Self.nagradeNiza.count - 1)] }

    @discardableResult
    func pokupiDnevnuNagradu(danas: Date = .now) -> Int {
        guard s.poslednjaNagrada != Self.dan(danas) else { return 0 }
        let juce = Self.dan(danas.addingTimeInterval(-86_400))
        s.danaNagrade = s.poslednjaNagrada == juce ? s.danaNagrade + 1 : 0
        let iznos = Self.nagradeNiza[min(s.danaNagrade, Self.nagradeNiza.count - 1)]
        s.novcici += iznos
        s.poslednjaNagrada = Self.dan(danas)
        if let i = s.poruke.firstIndex(where: { $0.vrsta == .nagrada && !$0.pokupljeno }) { s.poruke[i].pokupljeno = true; s.poruke[i].procitano = true }
        sacuvaj()
        return iznos
    }

    // MARK: Prodavnica

    enum Pomoc: String, CaseIterable, Identifiable {
        case polaPola, nagovestaj, vreme, preskok
        var id: String { rawValue }
        var naziv: String { switch self { case .polaPola: "50/50 ×5"; case .nagovestaj: "Nagoveštaj ×5"; case .vreme: "+10 s ×5"; case .preskok: "Preskok ×5" } }
        var cena: Int { switch self { case .polaPola: 100; case .nagovestaj: 150; case .vreme: 120; case .preskok: 200 } }
        var ikonica: String { switch self { case .polaPola: "circle.lefthalf.filled"; case .nagovestaj: "lightbulb"; case .vreme: "timer"; case .preskok: "forward.end" } }
        var opis: String {
            switch self {
            case .polaPola: "Uklanja dva netačna odgovora."
            case .nagovestaj: "Maskota sklanja jedan netačan odgovor i daje trag."
            case .vreme: "Deset sekundi više na jednom pitanju."
            case .preskok: "Preskače pitanje bez gubitka niza."
            }
        }
    }

    enum Kupovina: Equatable { case uspeh, nemaNovcica }

    func kupi(_ p: Pomoc) -> Kupovina {
        guard s.novcici >= p.cena else { return .nemaNovcica }
        s.novcici -= p.cena
        s.pomoci[p.rawValue, default: 0] += 5
        sacuvaj()
        return .uspeh
    }

    func imaPomoc(_ p: Pomoc) -> Int { s.pomoci[p.rawValue] ?? 0 }

    func potrosi(_ p: Pomoc) -> Bool {
        guard imaPomoc(p) > 0 else { return false }
        s.pomoci[p.rawValue, default: 0] -= 1
        sacuvaj()
        return true
    }

    func dodajNovcice(_ n: Int) { s.novcici += n; sacuvaj() }
    func oduzmiNovcice(_ n: Int) -> Bool { guard s.novcici >= n else { return false }; s.novcici -= n; sacuvaj(); return true }

    // MARK: Sanduče

    var neprocitanih: Int { s.poruke.filter { !$0.procitano }.count }

    func dodajPoruku(_ p: Poruka) { s.poruke.insert(p, at: 0); s.poruke = Array(s.poruke.prefix(100)); sacuvaj() }
    func procitajSve() { for i in s.poruke.indices { s.poruke[i].procitano = true }; sacuvaj() }
    func obrisiPoruku(_ id: String) { s.poruke.removeAll { $0.id == id }; sacuvaj() }

    /// Jednom dnevno, ako nagrada čeka, ubacuje podsetnik u sanduče.
    func osveziSanduce() {
        guard dnevnaNagradaSpremna, !s.poruke.contains(where: { $0.vrsta == .nagrada && !$0.pokupljeno }) else { return }
        dodajPoruku(Poruka(vrsta: .nagrada, naslov: "Dnevna nagrada je spremna",
                           tekst: "Dan \(s.danaNagrade + 1) niza: \(sledecaNagrada) novčića čeka.", vreme: .now, novcici: sledecaNagrada))
    }

    // MARK: Podešavanja i uvod

    func podesi(_ izmena: (inout Stanje) -> Void) { izmena(&s); sacuvaj() }

    /// Zakazuje dnevni podsetnik u 19:30 (ili ga gasi).
    func zakaziPodsetnik() async {
        let centar = UNUserNotificationCenter.current()
        centar.removePendingNotificationRequests(withIdentifiers: ["dnevni"])
        guard s.podsetnik else { return }
        let sadrzaj = UNMutableNotificationContent()
        sadrzaj.title = "Librum kviz"
        sadrzaj.body = "Niz od \(max(1, s.nizDana)) dana te čeka. Jedan kviz i čuvaš ga."
        var vreme = DateComponents(); vreme.hour = 19; vreme.minute = 30
        try? await centar.add(UNNotificationRequest(identifier: "dnevni", content: sadrzaj, trigger: UNCalendarNotificationTrigger(dateMatching: vreme, repeats: true)))
    }

    // MARK: Statistika

    /// Tačnost po danima za poslednjih `dana` dana (nil = nije igrano).
    func tacnostPoDanima(_ dana: Int, danas: Date = .now) -> [(dan: Date, tacnost: Double?)] {
        (0..<dana).reversed().map { i in
            let d = danas.addingTimeInterval(Double(-i) * 86_400)
            let st = s.dani[Self.dan(d)]
            let ukupno = (st?.tacnih ?? 0) + (st?.netacnih ?? 0)
            return (d, ukupno > 0 ? Double(st!.tacnih) / Double(ukupno) : nil)
        }
    }

    func tacnost(od: Date?) -> (tacnost: Double, igara: Int)? {
        let granica = od.map { Self.dan($0) } ?? ""
        let izabrani = s.dani.filter { $0.key >= granica }.values
        let t = izabrani.reduce(0) { $0 + $1.tacnih }, n = izabrani.reduce(0) { $0 + $1.netacnih }
        let igara = izabrani.reduce(0) { $0 + $1.igara }
        return t + n == 0 ? nil : (Double(t) / Double(t + n), igara)
    }

    // MARK: Bedževi

    static let sviBedzevi: [Bedz] = [
        Bedz(id: "prvi", naziv: "Prvi korak", opis: "Odigraj prvi kviz.", ikonica: "flag.fill", boja: 0x12907E, nagrada: 50),
        Bedz(id: "niz3", naziv: "Na vatri", opis: "Igraj 3 dana zaredom.", ikonica: "flame.fill", boja: 0xFF5FA2, nagrada: 100),
        Bedz(id: "niz7", naziv: "Nedelja znanja", opis: "Igraj 7 dana zaredom.", ikonica: "calendar", boja: 0xF4A33C, nagrada: 200),
        Bedz(id: "niz30", naziv: "Mesec bez pauze", opis: "Igraj 30 dana zaredom.", ikonica: "crown.fill", boja: 0xFFD84D, nagrada: 500),
        Bedz(id: "tacnih100", naziv: "Veliki mozak", opis: "100 tačnih odgovora.", ikonica: "brain.head.profile", boja: 0x6D4BC9, nagrada: 100),
        Bedz(id: "tacnih1000", naziv: "Enciklopedija", opis: "1.000 tačnih odgovora.", ikonica: "books.vertical.fill", boja: 0x6D4BC9, nagrada: 300),
        Bedz(id: "savrseno", naziv: "Savršenih 10", opis: "10 od 10 u jednom kvizu.", ikonica: "star.fill", boja: 0xFFD84D, nagrada: 150),
        Bedz(id: "brzina", naziv: "Munja", opis: "10 tačnih odgovora za manje od 2 sekunde.", ikonica: "bolt.fill", boja: 0x12907E, nagrada: 100),
        Bedz(id: "igara25", naziv: "Stalni gost", opis: "Odigraj 25 kvizova.", ikonica: "gamecontroller.fill", boja: 0x6EC3F2, nagrada: 100),
        Bedz(id: "igara100", naziv: "Kvizomanija", opis: "Odigraj 100 kvizova.", ikonica: "trophy.fill", boja: 0xF4A33C, nagrada: 300),
        Bedz(id: "duel1", naziv: "Prva pobeda", opis: "Pobedi u duelu.", ikonica: "person.2.fill", boja: 0xFF5FA2, nagrada: 100),
        Bedz(id: "duel10", naziv: "Šampion", opis: "Pobedi u 10 duela.", ikonica: "medal.fill", boja: 0xFFD84D, nagrada: 300),
        Bedz(id: "svet", naziv: "Svetski putnik", opis: "Odigraj Osvajanje sveta.", ikonica: "globe.europe.africa.fill", boja: 0x6EC3F2, nagrada: 100),
        Bedz(id: "knjige", naziv: "Knjiški moljac", opis: "50 tačnih u Book kvizu.", ikonica: "book.fill", boja: 0xF4A33C, nagrada: 150),
        Bedz(id: "nivo5", naziv: "Nivo 5", opis: "Dostigni nivo 5.", ikonica: "chart.line.uptrend.xyaxis", boja: 0x12907E, nagrada: 200),
        Bedz(id: "nivo10", naziv: "Nivo 10", opis: "Dostigni nivo 10.", ikonica: "sparkles", boja: 0x6D4BC9, nagrada: 500),
    ]

    private func ispunjen(_ id: String) -> Bool {
        switch id {
        case "prvi": s.igara >= 1
        case "niz3": s.najduziNiz >= 3
        case "niz7": s.najduziNiz >= 7
        case "niz30": s.najduziNiz >= 30
        case "tacnih100": s.tacnih >= 100
        case "tacnih1000": s.tacnih >= 1000
        case "savrseno": s.savrsenih >= 1
        case "brzina": s.brzihOdgovora >= 10
        case "igara25": s.igara >= 25
        case "igara100": s.igara >= 100
        case "duel1": s.pobedaDuel >= 1
        case "duel10": s.pobedaDuel >= 10
        case "svet": (s.najbolje["osvajanje"] ?? -1) >= 0
        case "knjige": (s.kategorije.filter { $0.key.hasPrefix("Knjige") }.values.reduce(0) { $0 + $1[0] }) >= 50
        case "nivo5": nivo >= 5
        case "nivo10": nivo >= 10
        default: false
        }
    }

    private func proveriBedzeve(_ danas: Date) -> [Bedz] {
        let novi = Self.sviBedzevi.filter { s.bedzevi[$0.id] == nil && ispunjen($0.id) }
        for b in novi {
            s.bedzevi[b.id] = danas
            s.novcici += b.nagrada
            s.poruke.insert(Poruka(vrsta: .bedz, naslov: "Novi bedž: \(b.naziv)", tekst: "\(b.opis) +\(b.nagrada) novčića.", vreme: danas), at: 0)
        }
        return novi
    }

    // MARK: Čuvanje

    static func dan(_ d: Date) -> String {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        let c = k.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func sacuvaj() {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: kljuc) }
    }

    /// Za testove i brisanje naloga: vraća sve na početak.
    func resetuj() { s = Stanje(); sacuvaj() }
}
