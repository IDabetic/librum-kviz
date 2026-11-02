import Foundation

/// Pravila PRO kviza, ista kao src/app/pro-kviz/start/page.tsx, da rezultat
/// iz aplikacije stoji ravnopravno na istoj rang listi.
struct ProKviz: Equatable {
    static let sekundi = 15
    static let pocetniZivoti = 10
    static let poenaTacno = 10
    static let poenaNetacno = 5
    static let riskBonus = 10
    static let riskZivoti = 2
    static let riskPoena = 10
    static let svakihZaNagradu = 50
    static let zivotaNagrada = 5
    static let komboBonusi: [Int: (poena: Int, poruka: String)] = [
        5: (10, "Lep niz!"), 10: (25, "Odličan ritam!"), 20: (60, "Ozbiljno znanje!"),
        50: (150, "Librum mašina!"), 100: (400, "Živa enciklopedija!"),
    ]
    /// Book kviz ima istu skalu, samo drugu poruku na 50.
    var porukaZa50 = "Librum mašina!"


    var zivoti = pocetniZivoti
    var poeni = 0
    var stigao = 0
    var tacnih = 0
    var netacnih = 0
    var preskoceno = 0
    var kombo = 0
    var najboljiKombo = 0
    var polaPola = 1
    var preskoci = 1
    var dodatnoVreme = 1
    var iskorisceno = (polaPola: 0, preskoci: 0, dodatnoVreme: 0)
    var riskAktivan = false
    var poslednjiRisk = 0
    var riskPokusaja = 0
    var riskTacnih = 0
    var riskNetacnih = 0

    var gotovo: Bool { zivoti <= 0 }

    /// Risk jednom po bloku od 10 pitanja.
    var riskDostupan: Bool {
        !riskAktivan && (poslednjiRisk == 0 || stigao / 10 > (poslednjiRisk - 1) / 10)
    }

    static func == (a: ProKviz, b: ProKviz) -> Bool {
        a.zivoti == b.zivoti && a.poeni == b.poeni && a.stigao == b.stigao && a.kombo == b.kombo && a.riskAktivan == b.riskAktivan
    }

    /// Primenjuje odgovor; vraća poruku za prikaz (kombo ili nagrada), ako je ima.
    mutating func odgovor(tacan: Bool, nagrada: () -> Int = { Int.random(in: 0..<3) }) -> String? {
        stigao += 1
        var poruka: String?
        if tacan {
            poeni += riskAktivan ? Self.poenaTacno + Self.riskBonus : Self.poenaTacno
            kombo += 1
            najboljiKombo = max(najboljiKombo, kombo)
            tacnih += 1
            if riskAktivan { riskTacnih += 1 }
            if let b = Self.komboBonusi[kombo] { poeni += b.poena; poruka = "\(kombo == 50 ? porukaZa50 : b.poruka) +\(b.poena)" }
            if stigao % Self.svakihZaNagradu == 0 {
                zivoti += Self.zivotaNagrada
                switch nagrada() { case 0: polaPola += 1; case 1: preskoci += 1; default: dodatnoVreme += 1 }
                poruka = "Preživeo/la si \(stigao) pitanja! +\(Self.zivotaNagrada) života + bonus pomoć"
            }
        } else {
            zivoti -= riskAktivan ? Self.riskZivoti : 1
            poeni = max(0, poeni - (riskAktivan ? Self.riskPoena : Self.poenaNetacno))
            netacnih += 1
            kombo = 0
            if riskAktivan { riskNetacnih += 1 }
        }
        riskAktivan = false
        return poruka
    }

    mutating func aktivirajRisk() {
        guard riskDostupan else { return }
        riskAktivan = true
        poslednjiRisk = stigao + 1
        riskPokusaja += 1
    }

    mutating func iskoristiPreskok() -> Bool {
        guard preskoci > 0 else { return false }
        preskoci -= 1; iskorisceno.preskoci += 1; preskoceno += 1; stigao += 1; riskAktivan = false
        return true
    }

    /// Red za book_sessions: iste kolone kao PRO, bez Risk polja (Book nema Risk).
    func redBook(korisnik: String, sekundi: Int) -> [String: Any] {
        var r = red(korisnik: korisnik, sekundi: sekundi)
        for k in ["risk_attempts", "risk_correct", "risk_wrong"] { r.removeValue(forKey: k) }
        return r
    }

    /// Red za tabelu survivor_sessions (iste kolone kao veb).
    func red(korisnik: String, sekundi: Int) -> [String: Any] {
        let odgovoreno = tacnih + netacnih
        let tacnost = odgovoreno > 0 ? (Double(tacnih) / Double(odgovoreno) * 10000).rounded() / 100 : 0
        return [
            "user_id": korisnik, "score": poeni, "questions_reached": stigao, "correct_answers": tacnih,
            "wrong_answers": netacnih, "skipped_questions": preskoceno, "accuracy": tacnost, "best_combo": najboljiKombo,
            "total_time_seconds": sekundi,
            "used_lifelines": ["fiftyFifty": iskorisceno.polaPola, "skip": iskorisceno.preskoci, "extraTime": iskorisceno.dodatnoVreme],
            "risk_attempts": riskPokusaja, "risk_correct": riskTacnih, "risk_wrong": riskNetacnih,
        ]
    }
}
