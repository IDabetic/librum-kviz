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
}

/// Lokalni napredak igrača: XP, niz dana, pomoći, bedževi, statistika i sanduče.
/// Čuva se na uređaju (UserDefaults), radi i bez naloga i bez mreže.
/// shortcut: samo na uređaju; kad Supabase proradi, sinhronizacija ide u tabelu po nalogu.
@Observable
@MainActor
final class Napredak {
    static let deljeni = Napredak()

    struct Dan: Codable { var igara = 0; var tacnih = 0; var netacnih = 0 }
    struct Poruka: Codable, Identifiable {
        enum Vrsta: String, Codable { case bedz, izazov, rezultat, pratilac }
        var id = UUID().uuidString
        let vrsta: Vrsta
        let naslov: String
        let tekst: String
        let vreme: Date
        var procitano = false
        /// Za izazov: kod sobe duela i ko izaziva.
        var kodSobe: String? = nil
        var odKoga: String? = nil
    }
    struct Stanje: Codable {
        var xp = 0
        var nizDana = 0
        var najduziNiz = 0
        var poslednjiDanIgre: String?
        var igara = 0
        var tacnih = 0
        var netacnih = 0
        var savrsenih = 0
        var brzihOdgovora = 0
        var pobedaDuel = 0
        var zbirMs = 0
        var brojMs = 0
        /// Dnevni fond pomoći: ciklus počinje prvom pomoći, posle 24 h fond je opet pun.
        var pocetakCiklusaPomoci: Date?
        var pomociIskorisceno = 0
        var bedzevi: [String: Date] = [:]
        var dani: [String: Dan] = [:]
        var kategorije: [String: [Int]] = [:]   // naziv → [tačnih, ukupno]
        var najbolje: [String: Int] = [:]        // kviz → najbolji broj tačnih
        var poruke: [Poruka] = []
        var cilj = 3
        var podsetnik = true
        /// Prihvaćena pravila zajednice (pre prve objave, komentara ili poruke; Apple 1.2).
        var pravilaZajednice = false
        var maskota = "Mimi"
        /// Avatar (oznaka „s3:2:4”); kod prijavljenog ide i u profiles.avatar.
        var avatar: String?
        /// Koliko puta je koja pomoć korišćena (50/50, nagoveštaj…), za profil.
        var pomociPoVrsti: [String: Int] = [:]
        var partijaSaPomoci = 0
        var interesovanja: [String] = []
        var uvodZavrsen = false
        var zvuk = true
        var muzika = false
    }

    private(set) var s: Stanje
    private let kljuc = "napredak.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: kljuc), let st = Self.ucitaj(d) {
            s = st
        } else {
            s = Stanje()
        }
    }

    /// Sačuvano stanje preko podrazumevanog: polje dodato u novoj verziji dobija početnu
    /// vrednost umesto da cela dekodacija padne i igrač izgubi napredak.
    nonisolated static func ucitaj(_ d: Data) -> Stanje? {
        guard let sacuvano = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let osnova = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(Stanje())) as? [String: Any],
              let spojeno = try? JSONSerialization.data(withJSONObject: osnova.merging(sacuvano) { _, novo in novo }) else { return nil }
        return try? JSONDecoder().decode(Stanje.self, from: spojeno)
    }

    // MARK: Nivo

    static let xpPoNivou = 250
    /// Nivo n traži 250 × n XP da se pređe u n+1 (1→2 = 250, 12→13 = 3.000).
    var nivo: Int { Self.nivo(xp: s.xp).nivo }
    var xpUNivou: (imam: Int, treba: Int) { let n = Self.nivo(xp: s.xp); return (n.ostatak, n.nivo * Self.xpPoNivou) }

    /// Titula po nivou (docs/NAPREDAK.md).
    static func titula(_ nivo: Int) -> String {
        switch nivo { case ..<5: "Početnik"; case ..<10: "Znalac"; case ..<20: "Erudita"; case ..<35: "Mudrac"; default: "Legenda" }
    }
    var titula: String { Self.titula(nivo) }

    /// XP za partiju: 10 po tačnom, 20 za završenu partiju, 50 za pobedu; niz dana dodaje do +50%.
    static func xpZaPartiju(tacnih: Int, pobeda: Bool, niz: Int) -> Int {
        let osnova = tacnih * 10 + 20 + (pobeda ? 50 : 0)
        return osnova + osnova * min(max(niz, 1) - 1, 10) / 20
    }

    static func nivo(xp: Int) -> (nivo: Int, ostatak: Int) {
        var n = 1, ostatak = xp
        while ostatak >= n * xpPoNivou { ostatak -= n * xpPoNivou; n += 1 }
        return (n, ostatak)
    }

    // MARK: Igra

    struct Ishod { let xp: Int; let noviBedzevi: [Bedz] }

    /// Upisuje odigranu igru; vraća zarađeno i nove bedževe.
    @discardableResult
    func zabeleziIgru(kviz: String, tacnih: Int, netacnih: Int, kategorija: String? = nil, brzih: Int = 0, pobeda: Bool = false, prosekMs: Int? = nil, danas: Date = .now) -> Ishod {
        let dan = Self.dan(danas)
        if s.poslednjiDanIgre != dan {
            s.nizDana = s.poslednjiDanIgre == Self.dan(danas.addingTimeInterval(-86_400)) ? s.nizDana + 1 : 1
            s.najduziNiz = max(s.najduziNiz, s.nizDana)
            s.poslednjiDanIgre = dan
        }
        let xp = Self.xpZaPartiju(tacnih: tacnih, pobeda: pobeda, niz: s.nizDana)
        s.xp += xp
        s.igara += 1
        s.tacnih += tacnih
        s.netacnih += netacnih
        s.brzihOdgovora += brzih
        if pomocUPartiji != nil { s.partijaSaPomoci += 1 }
        if let prosekMs, tacnih + netacnih > 0 { s.zbirMs += prosekMs * (tacnih + netacnih); s.brojMs += tacnih + netacnih }
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
        return Ishod(xp: xp, noviBedzevi: novi)
    }

    /// Prosečna brzina odgovora u sekundama (nil dok nema merenja).
    var prosecnaBrzina: Double? { s.brojMs > 0 ? Double(s.zbirMs) / Double(s.brojMs) / 1000 : nil }

    // MARK: Pomoć

    /// Vlasnikovo pravilo (02.11): 7 pomoći dnevno, zajedničkih za svih 7 igara, najviše
    /// jedna po partiji (to čuva sama igra). Kad se potroše, sledeće stižu 24 h posle prve.
    static let pomociDnevno = 7
    static let ciklusPomoci: TimeInterval = 24 * 3600

    enum Pomoc: String, CaseIterable, Identifiable {
        case polaPola, nagovestaj, vreme, preskok
        var id: String { rawValue }
        var naziv: String { switch self { case .polaPola: "50/50"; case .nagovestaj: "Nagoveštaj"; case .vreme: "+10 sekundi"; case .preskok: "Preskok" } }
        var ikonica: String { switch self { case .polaPola: "circle.lefthalf.filled"; case .nagovestaj: "lightbulb"; case .vreme: "timer"; case .preskok: "forward.end" } }
    }

    private func ciklusIstekao(_ sada: Date) -> Bool {
        s.pocetakCiklusaPomoci.map { sada.timeIntervalSince($0) >= Self.ciklusPomoci } ?? true
    }

    /// Dnevni fond: 7, +1 na svakih 5 nivoa (najviše +3), +1 za niz od 3 dana, +2 od 7 dana.
    static func fond(nivo: Int, niz: Int) -> Int { pomociDnevno + min(3, (nivo - 1) / 5) + (niz >= 7 ? 2 : niz >= 3 ? 1 : 0) }
    var fondPomoci: Int { Self.fond(nivo: nivo, niz: s.nizDana) }

    /// Koliko pomoći je ostalo u tekućem ciklusu.
    func pomociOstalo(sada: Date = .now) -> Int {
        ciklusIstekao(sada) ? fondPomoci : max(0, fondPomoci - s.pomociIskorisceno)
    }

    /// Kada se fond puni (nil dok nijedna pomoć nije potrošena u ovom ciklusu).
    func sledeciFondPomoci(sada: Date = .now) -> Date? {
        guard !ciklusIstekao(sada), let pocetak = s.pocetakCiklusaPomoci else { return nil }
        return pocetak.addingTimeInterval(Self.ciklusPomoci)
    }

    /// Pomoć iskorišćena u partiji koja traje; zavrsiPartiju je upisuje uz rezultat.
    var pomocUPartiji: String?

    /// Troši jednu pomoć iz dnevnog fonda; false kad je fond prazan.
    func iskoristiPomoc(_ vrsta: String = "pomoc", sada: Date = .now) -> Bool {
        if ciklusIstekao(sada) { s.pocetakCiklusaPomoci = sada; s.pomociIskorisceno = 0 }
        guard s.pomociIskorisceno < fondPomoci else { return false }
        s.pomociIskorisceno += 1
        s.pomociPoVrsti[vrsta, default: 0] += 1
        pomocUPartiji = vrsta
        sacuvaj()
        return true
    }


    // MARK: Sanduče

    var neprocitanih: Int { s.poruke.filter { !$0.procitano }.count }

    func dodajPoruku(_ p: Poruka) { s.poruke.insert(p, at: 0); s.poruke = Array(s.poruke.prefix(100)); sacuvaj() }
    func procitajSve() { for i in s.poruke.indices { s.poruke[i].procitano = true }; sacuvaj() }
    func obrisiPoruku(_ id: String) { s.poruke.removeAll { $0.id == id }; sacuvaj() }

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
        Bedz(id: "prvi", naziv: "Prvi korak", opis: "Odigraj prvi kviz.", ikonica: "flag.fill", boja: 0x12907E),
        Bedz(id: "niz3", naziv: "Na vatri", opis: "Igraj 3 dana zaredom.", ikonica: "flame.fill", boja: 0xFF5FA2),
        Bedz(id: "niz7", naziv: "Nedelja znanja", opis: "Igraj 7 dana zaredom.", ikonica: "calendar", boja: 0xF4A33C),
        Bedz(id: "niz30", naziv: "Mesec bez pauze", opis: "Igraj 30 dana zaredom.", ikonica: "crown.fill", boja: 0xFFD84D),
        Bedz(id: "tacnih100", naziv: "Veliki mozak", opis: "100 tačnih odgovora.", ikonica: "brain.head.profile", boja: 0x6D4BC9),
        Bedz(id: "tacnih1000", naziv: "Enciklopedija", opis: "1.000 tačnih odgovora.", ikonica: "books.vertical.fill", boja: 0x6D4BC9),
        Bedz(id: "savrseno", naziv: "Savršenih 10", opis: "10 od 10 u jednom kvizu.", ikonica: "star.fill", boja: 0xFFD84D),
        Bedz(id: "brzina", naziv: "Munja", opis: "10 tačnih odgovora za manje od 2 sekunde.", ikonica: "bolt.fill", boja: 0x12907E),
        Bedz(id: "igara25", naziv: "Stalni gost", opis: "Odigraj 25 kvizova.", ikonica: "gamecontroller.fill", boja: 0x6EC3F2),
        Bedz(id: "igara100", naziv: "Kvizomanija", opis: "Odigraj 100 kvizova.", ikonica: "trophy.fill", boja: 0xF4A33C),
        Bedz(id: "duel1", naziv: "Prva pobeda", opis: "Pobedi u duelu.", ikonica: "person.2.fill", boja: 0xFF5FA2),
        Bedz(id: "duel10", naziv: "Šampion", opis: "Pobedi u 10 duela.", ikonica: "medal.fill", boja: 0xFFD84D),
        Bedz(id: "svet", naziv: "Svetski putnik", opis: "Odigraj Osvajanje sveta.", ikonica: "globe.europe.africa.fill", boja: 0x6EC3F2),
        Bedz(id: "knjige", naziv: "Knjiški moljac", opis: "50 tačnih u Book kvizu.", ikonica: "book.fill", boja: 0xF4A33C),
        Bedz(id: "nivo5", naziv: "Nivo 5", opis: "Dostigni nivo 5.", ikonica: "chart.line.uptrend.xyaxis", boja: 0x12907E),
        Bedz(id: "nivo10", naziv: "Nivo 10", opis: "Dostigni nivo 10.", ikonica: "sparkles", boja: 0x6D4BC9),
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
            s.poruke.insert(Poruka(vrsta: .bedz, naslov: "Novi bedž: \(b.naziv)", tekst: b.opis, vreme: danas), at: 0)
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
